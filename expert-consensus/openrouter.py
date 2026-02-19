#!/usr/bin/env python3
"""
openrouter — Query the world's best AI models from your terminal.

One script, one API key. Configurable expert panel for multi-model consensus.

Setup:
    pip install openai
    export OPENROUTER_API_KEY=sk-or-...

Usage:
    openrouter "Explain quantum computing" -m claude
    openrouter "What's in this?" --image photo.png -m gemini
    openrouter --panel                              # Show your expert team
    openrouter --all "Compare React vs Svelte"      # Fan out to all enabled models
    openrouter --list-models --pricing
    openrouter --aliases

Config:
    Copy panel.json next to this script to customize your expert team.
    Toggle "enabled" to add/remove models from the panel.
"""

import os
import sys
import argparse
import json
import base64
import mimetypes
from pathlib import Path
import time
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from openai import OpenAI
except ImportError:
    print("Error: pip install openai", file=sys.stderr)
    sys.exit(1)

try:
    from dotenv import load_dotenv
    for env_path in [Path('.env'), Path.home() / '.env', Path(__file__).resolve().parent / '.env']:
        if env_path.exists():
            load_dotenv(env_path)
            break
except ImportError:
    pass

# ── Default Expert Panel ─────────────────────────────────────────────────
# One per provider. Latest flagship reasoning model.
# Override by placing panel.json next to this script.
# Updated: Feb 19, 2026

DEFAULT_PANEL = [
    {"alias": "claude",   "model": "anthropic/claude-opus-4.6",      "enabled": True,  "provider": "Anthropic", "strength": "Deepest reasoning, edge cases"},
    {"alias": "gpt",      "model": "openai/gpt-5.2",                 "enabled": True,  "provider": "OpenAI",    "strength": "Strong all-round, structured output"},
    {"alias": "gemini",   "model": "google/gemini-3-pro-preview",     "enabled": True,  "provider": "Google",    "strength": "Creative connections, multimodal"},
    {"alias": "deepseek", "model": "deepseek/deepseek-r1",            "enabled": True,  "provider": "DeepSeek",  "strength": "Best open-source reasoning"},
    {"alias": "llama",    "model": "meta-llama/llama-4-maverick",     "enabled": True,  "provider": "Meta",      "strength": "128-expert MoE, multimodal"},
    {"alias": "grok",     "model": "x-ai/grok-4",                    "enabled": True,  "provider": "xAI",       "strength": "Contrarian, evidence citations"},
    {"alias": "kimi",     "model": "moonshotai/kimi-k2.5",           "enabled": True,  "provider": "Moonshot",  "strength": "Best value, deep domain knowledge"},
    {"alias": "glm",      "model": "z-ai/glm-5",                     "enabled": True,  "provider": "ZHIPU",     "strength": "Factual accuracy, catches errors"},
    {"alias": "qwen",     "model": "qwen/qwen3.5-397b-a17b",         "enabled": True,  "provider": "Alibaba",   "strength": "Native multimodal, 201 languages"},
]

# Variant suffixes (append with colon, e.g. "claude:online")
MODEL_VARIANTS = {
    'online':   ':online',
    'nitro':    ':nitro',
    'floor':    ':floor',
    'free':     ':free',
    'extended': ':extended',
}


def load_panel() -> list:
    """Load panel from panel.json if it exists, otherwise use defaults."""
    config_path = Path(__file__).resolve().parent / 'panel.json'
    if config_path.exists():
        try:
            with open(config_path) as f:
                return json.load(f)
        except (json.JSONDecodeError, KeyError) as e:
            print(f"Warning: Invalid panel.json ({e}), using defaults", file=sys.stderr)
    return DEFAULT_PANEL


def get_aliases(panel: list) -> dict:
    """Build alias -> model ID mapping from panel (all entries, not just enabled)."""
    return {entry['alias']: entry['model'] for entry in panel}


def get_enabled_aliases(panel: list) -> list:
    """Get list of enabled alias names."""
    return [entry['alias'] for entry in panel if entry.get('enabled', True)]


PANEL = load_panel()
MODEL_ALIASES = get_aliases(PANEL)
DEFAULT_MODEL = next((e['model'] for e in PANEL if e['alias'] == 'claude'), PANEL[0]['model'])


def resolve_model(model_str: str) -> str:
    """Resolve alias to full model ID, handling variant suffixes."""
    variant_suffix = ''
    if ':' in model_str:
        base, variant = model_str.split(':', 1)
        if variant in MODEL_VARIANTS:
            variant_suffix = MODEL_VARIANTS[variant]
            model_str = base
        else:
            return model_str
    return MODEL_ALIASES.get(model_str.lower(), model_str) + variant_suffix


def encode_image(path: Path) -> tuple:
    mime_type, _ = mimetypes.guess_type(str(path))
    if mime_type not in ['image/png', 'image/jpeg', 'image/webp', 'image/gif']:
        mime_type = 'image/png'
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode('utf-8')
    return f"data:{mime_type};base64,{data}", mime_type


class OpenRouterClient:
    def __init__(self):
        self.api_key = os.getenv('OPENROUTER_API_KEY')
        if not self.api_key:
            print("Error: OPENROUTER_API_KEY not set.", file=sys.stderr)
            print("  export OPENROUTER_API_KEY=sk-or-...", file=sys.stderr)
            print("  Get one at: https://openrouter.ai/keys", file=sys.stderr)
            sys.exit(1)
        self.client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=self.api_key)

    def list_models(self, pricing: bool = False, filter_str: str = None):
        try:
            models = self.client.models.list().data
            if filter_str:
                models = [m for m in models if filter_str.lower() in m.id.lower()]
            if pricing:
                print(f"Models ({len(models)}):")
                for m in sorted(models, key=lambda x: x.id):
                    p = ""
                    if hasattr(m, 'pricing') and m.pricing:
                        p = f"  ${m.pricing.get('prompt', '?')}/{m.pricing.get('completion', '?')} /1M"
                    print(f"  {m.id}{p}")
            else:
                for m in sorted(models, key=lambda x: x.id):
                    print(m.id)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)

    def generate(self, prompt: str, model: str = None,
                 system: str = None, stream: bool = True,
                 images: list = None, temperature: float = None,
                 max_tokens: int = None, web_search: bool = False,
                 json_mode: bool = False, reasoning: str = None,
                 fallbacks: list = None, no_stream: bool = False) -> dict:
        model = model or DEFAULT_MODEL
        try:
            msgs = []
            if system:
                msgs.append({"role": "system", "content": system})
            if images:
                content = [{"type": "text", "text": prompt}]
                for img in images:
                    p = Path(img)
                    if not p.exists():
                        return {'ok': False, 'error': f"Image not found: {img}"}
                    url, _ = encode_image(p)
                    content.append({"type": "image_url", "image_url": {"url": url}})
                msgs.append({"role": "user", "content": content})
            else:
                msgs.append({"role": "user", "content": prompt})

            params = {"model": model, "messages": msgs, "stream": stream and not no_stream}
            if temperature is not None:
                params["temperature"] = temperature
            if max_tokens:
                params["max_tokens"] = max_tokens
            if json_mode:
                params["response_format"] = {"type": "json_object"}

            extra = {}
            if reasoning:
                extra["reasoning"] = {"effort": reasoning}
            if web_search:
                extra["plugins"] = [{"id": "web"}]
            if fallbacks:
                extra["models"] = [model] + [resolve_model(m) for m in fallbacks]
            if extra:
                params["extra_body"] = extra

            t0 = time.time()
            if params["stream"]:
                chunks = []
                for chunk in self.client.chat.completions.create(**params):
                    if chunk.choices and chunk.choices[0].delta.content:
                        text = chunk.choices[0].delta.content
                        chunks.append(text)
                        print(text, end='', flush=True)
                print()
                return {'ok': True, 'content': ''.join(chunks), 'model': model,
                        'time': round(time.time() - t0, 2)}
            else:
                r = self.client.chat.completions.create(**params)
                content = r.choices[0].message.content
                usage = r.usage
                return {
                    'ok': True, 'content': content, 'model': getattr(r, 'model', model),
                    'time': round(time.time() - t0, 2),
                    'tokens': usage.total_tokens if usage else 0,
                    'cost': getattr(usage, 'cost', None) if usage else None,
                }
        except Exception as e:
            return {'ok': False, 'error': str(e)}


def fan_out(client, prompt, aliases, system=None, images=None,
            temperature=None, max_tokens=None, web_search=False,
            json_mode=False, reasoning=None, output_dir=None, verbose=False):
    """Send prompt to multiple models in parallel, collect results."""
    results = {}

    def query_model(alias):
        model = resolve_model(alias)
        if verbose:
            print(f"  Querying {alias} ({model})...", file=sys.stderr)
        result = client.generate(
            prompt=prompt, model=model, system=system, images=images,
            temperature=temperature, max_tokens=max_tokens,
            web_search=web_search, json_mode=json_mode,
            reasoning=reasoning, no_stream=True, stream=False,
        )
        return alias, result

    with ThreadPoolExecutor(max_workers=len(aliases)) as executor:
        futures = {executor.submit(query_model, a): a for a in aliases}
        for future in as_completed(futures):
            alias, result = future.result()
            results[alias] = result

    # Print results in panel order
    for alias in aliases:
        result = results.get(alias, {'ok': False, 'error': 'No response'})
        print(f"\n{'='*60}")
        print(f"  {alias.upper()} ({MODEL_ALIASES.get(alias, alias)})")
        print(f"{'='*60}\n")
        if result['ok']:
            print(result['content'])
            if output_dir:
                out = Path(output_dir) / f"{alias}.md"
                out.write_text(result['content'])
            if verbose:
                parts = [f"Time: {result.get('time', 0)}s"]
                if result.get('tokens'):
                    parts.append(f"Tokens: {result['tokens']}")
                print(f"\n  [{' | '.join(parts)}]", file=sys.stderr)
        else:
            print(f"Error: {result['error']}")

    return results


def show_panel():
    """Display the current expert panel."""
    config_path = Path(__file__).resolve().parent / 'panel.json'
    source = "panel.json" if config_path.exists() else "defaults"
    enabled = [e for e in PANEL if e.get('enabled', True)]
    disabled = [e for e in PANEL if not e.get('enabled', True)]

    print(f"Expert Panel ({len(enabled)} active, from {source}):\n")
    w = max(len(e['alias']) for e in PANEL)
    for e in enabled:
        print(f"  {e['alias']:<{w+2}} {e['model']:<40} {e.get('strength', '')}")
    if disabled:
        print(f"\nDisabled ({len(disabled)}):")
        for e in disabled:
            print(f"  {e['alias']:<{w+2}} {e['model']}")
    print(f"\nEdit: {config_path}")


def main():
    p = argparse.ArgumentParser(
        description="Query the world's best AI models from your terminal",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Aliases (configurable via panel.json):
  claude, gpt, gemini, deepseek, llama, grok, kimi, glm, qwen

Variants (append :suffix): :online :nitro :floor :free :extended

Examples:
  openrouter "Explain quantum computing" -m claude
  openrouter "What's in this?" --image photo.png -m gemini
  openrouter "Latest AI news" -m claude --web
  openrouter --file prompt.md -m deepseek --no-stream > output.md
  echo "Summarize" | openrouter -m gpt
  openrouter --panel                          # Show expert team
  openrouter --all "Compare React vs Svelte"  # Fan out to all enabled models
  openrouter --list-models anthropic --pricing
""")

    p.add_argument('prompt', nargs='?', help='Prompt (or pipe via stdin)')
    p.add_argument('--file', '-f', help='Load prompt from file')
    p.add_argument('--model', '-m', default=None, help='Model or alias (default: claude)')
    p.add_argument('--system', '-s', help='System prompt')
    p.add_argument('--image', '-img', action='append', dest='images', help='Image file')
    p.add_argument('--web', '-w', action='store_true', help='Enable web search')
    p.add_argument('--temperature', '-t', type=float, help='Temperature (0-2)')
    p.add_argument('--max-tokens', type=int, help='Max output tokens')
    p.add_argument('--no-stream', action='store_true', help='Wait for full response')
    p.add_argument('--json-mode', action='store_true', help='JSON output')
    p.add_argument('--reasoning', help='Reasoning effort: high|medium|low')
    p.add_argument('--fallback', nargs='+', help='Fallback models')
    p.add_argument('--output', '-o', help='Save to file (single) or directory (--all)')
    p.add_argument('--verbose', '-v', action='store_true', help='Show metadata')
    p.add_argument('--list-models', nargs='?', const='', metavar='FILTER', help='List models')
    p.add_argument('--pricing', action='store_true', help='Show pricing')
    p.add_argument('--aliases', action='store_true', help='Show aliases')
    p.add_argument('--panel', action='store_true', help='Show expert panel')
    p.add_argument('--all', action='store_true', help='Fan out to all enabled models')

    args = p.parse_args()

    if args.panel:
        show_panel()
        return

    if args.aliases:
        print("Model aliases:")
        w = max(len(a) for a in MODEL_ALIASES)
        for alias, mid in sorted(MODEL_ALIASES.items()):
            print(f"  {alias:<{w + 2}} -> {mid}")
        print("\nVariants (append with colon, e.g. claude:online):")
        for name in sorted(MODEL_VARIANTS):
            print(f"  :{name}")
        return

    if args.list_models is not None:
        OpenRouterClient().list_models(pricing=args.pricing, filter_str=args.list_models or None)
        return

    # Resolve prompt
    prompt = args.prompt
    if not prompt and args.file:
        fp = Path(args.file)
        if not fp.exists():
            print(f"Error: {fp} not found", file=sys.stderr); sys.exit(1)
        prompt = fp.read_text().strip()
    elif not prompt and not sys.stdin.isatty():
        prompt = sys.stdin.read().strip()

    if not prompt:
        p.print_help(); sys.exit(1)

    client = OpenRouterClient()

    # Fan-out mode
    if args.all:
        enabled = get_enabled_aliases(PANEL)
        if not enabled:
            print("Error: No models enabled in panel", file=sys.stderr); sys.exit(1)
        output_dir = args.output
        if output_dir:
            Path(output_dir).mkdir(parents=True, exist_ok=True)
        print(f"Querying {len(enabled)} models: {', '.join(enabled)}", file=sys.stderr)
        fan_out(client, prompt, enabled, system=args.system, images=args.images,
                temperature=args.temperature, max_tokens=args.max_tokens,
                web_search=args.web, json_mode=args.json_mode,
                reasoning=args.reasoning, output_dir=output_dir, verbose=args.verbose)
        return

    # Single model mode
    model = resolve_model(args.model or 'claude')

    if args.verbose:
        parts = [f"Model: {model}"]
        if args.web: parts.append("Web: on")
        print(" | ".join(parts), file=sys.stderr)

    result = client.generate(
        prompt=prompt, model=model, system=args.system,
        images=args.images, temperature=args.temperature,
        max_tokens=args.max_tokens, web_search=args.web,
        json_mode=args.json_mode, reasoning=args.reasoning,
        fallbacks=args.fallback, no_stream=args.no_stream,
    )

    if not result['ok']:
        print(f"Error: {result['error']}", file=sys.stderr); sys.exit(1)

    if args.no_stream:
        print(result['content'])

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(result['content'])
        print(f"Saved: {args.output}", file=sys.stderr)

    if args.verbose:
        parts = [f"Time: {result.get('time', 0)}s"]
        if result.get('tokens'): parts.append(f"Tokens: {result['tokens']}")
        if result.get('cost') is not None: parts.append(f"Cost: ${result['cost']:.4f}")
        print(" | ".join(parts), file=sys.stderr)


if __name__ == "__main__":
    main()
