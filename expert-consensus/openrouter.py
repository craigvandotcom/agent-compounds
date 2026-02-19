#!/usr/bin/env python3
"""
openrouter — Query the world's best AI models from your terminal.

One script, one API key. Configurable expert panel for multi-model consensus.

Setup:
    pip install openai
    export OPENROUTER_API_KEY=sk-or-...

Usage:
    openrouter "prompt" -m anthropic/claude-opus-4.6         # Any model ID
    openrouter --all "Compare React vs Svelte"              # Fan out to panel
    openrouter --all --synthesize "Best API design patterns" # Fan out + synthesize
    openrouter --panel                                       # Show expert team

Config:
    Edit expert-panel.json next to this script. Any OpenRouter model ID works.
    Toggle "enabled" to add/remove models from the panel.
"""

import os
import sys
import argparse
import json
import base64
import mimetypes
from pathlib import Path
from typing import Optional
import time
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

# Variant suffixes (append with colon, e.g. "claude:online")
MODEL_VARIANTS = {
    'online':   ':online',
    'nitro':    ':nitro',
    'floor':    ':floor',
    'free':     ':free',
    'extended': ':extended',
}

SYNTHESIS_PROMPT = """You are not combining. You are not averaging. You are not selecting the best response and polishing it. You are using {count} independent views of the same question to reconstruct the answer they were all reaching toward.

Rules:
- When multiple models say the same thing in different words, that is high-confidence signal. State it once, precisely.
- When one model captures something no other mentions — and it's clearly correct — that is the sharpest insight in the set. Treasure it.
- When one model confidently states something that contradicts the weight of the others, that is noise. Remove it cleanly.
- When no model addresses something that obviously matters, fill the gap yourself.
- Density over length. Every sentence earns its place. Half the length, twice the insight.
- Precision over hedging. Not "it could be argued that X" — say "X is true when Y, false when Z."
- Find the organizing principle that makes everything obvious in retrospect.

Structure your response as:

## Consensus
The synthesized answer — the document all {count} models were trying to write.

## Agreement (High Confidence)
Where models converge. State each point once with conviction.

## Disagreement
Where models genuinely diverge. Name each position and what would resolve it.

## Unique Insights
Points only one model caught that add real value.

---
Original prompt: {prompt}

Responses:
{responses}"""


def _panel_path() -> Path:
    return Path(__file__).resolve().parent / "expert-panel.json"


def load_panel() -> list:
    """Load panel from expert-panel.json. Errors clearly if missing."""
    config = _panel_path()
    if not config.exists():
        print(f"Error: {config} not found.", file=sys.stderr)
        print("  Run: openrouter --init-panel", file=sys.stderr)
        sys.exit(1)
    try:
        with open(config) as f:
            panel = json.load(f)
        for entry in panel:
            if 'alias' not in entry or 'model' not in entry:
                raise KeyError(f"Missing 'alias' or 'model' in entry: {entry}")
        return panel
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error: Invalid expert-panel.json ({e})", file=sys.stderr)
        sys.exit(1)


def get_aliases(panel: list) -> dict:
    """Build alias -> model ID mapping from panel."""
    return {entry['alias']: entry['model'] for entry in panel}


def get_enabled(panel: list) -> list:
    """Get enabled panel entries."""
    return [e for e in panel if e.get('enabled', True)]


def get_enabled_aliases(panel: list) -> list:
    """Get list of enabled alias names."""
    return [e['alias'] for e in get_enabled(panel)]


# Lazy-loaded at first use so --init-panel works without expert-panel.json
_PANEL = None
_MODEL_ALIASES = None
_DEFAULT_MODEL = None


def _ensure_panel():
    global _PANEL, _MODEL_ALIASES, _DEFAULT_MODEL
    if _PANEL is None:
        _PANEL = load_panel()
        _MODEL_ALIASES = get_aliases(_PANEL)
        enabled = get_enabled(_PANEL)
        _DEFAULT_MODEL = enabled[0]['model'] if enabled else _PANEL[0]['model']


def resolve_model(model_str: str) -> str:
    """Resolve alias to full model ID, handling variant suffixes."""
    _ensure_panel()
    variant_suffix = ''
    if ':' in model_str:
        base, variant = model_str.split(':', 1)
        if variant in MODEL_VARIANTS:
            variant_suffix = MODEL_VARIANTS[variant]
            model_str = base
        else:
            return model_str
    return _MODEL_ALIASES.get(model_str.lower(), model_str) + variant_suffix


def encode_image(path: Path) -> str:
    """Encode an image file as a base64 data URL."""
    mime_type, _ = mimetypes.guess_type(str(path))
    if mime_type not in ('image/png', 'image/jpeg', 'image/webp', 'image/gif'):
        mime_type = 'image/png'
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode('utf-8')
    return f"data:{mime_type};base64,{data}"


class OpenRouterClient:
    """Thin wrapper around the OpenRouter API."""

    def __init__(self) -> None:
        self.api_key = os.getenv('OPENROUTER_API_KEY')
        if not self.api_key:
            print("Error: OPENROUTER_API_KEY not set.", file=sys.stderr)
            print("  export OPENROUTER_API_KEY=sk-or-...", file=sys.stderr)
            print("  Get one at: https://openrouter.ai/keys", file=sys.stderr)
            sys.exit(1)
        self.client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=self.api_key)

    def list_models(self, pricing: bool = False, filter_str: Optional[str] = None) -> list:
        """List available models, optionally with pricing."""
        try:
            models = self.client.models.list().data
            if filter_str:
                models = [m for m in models if filter_str.lower() in m.id.lower()]
            results = []
            for m in sorted(models, key=lambda x: x.id):
                price = ""
                if pricing and hasattr(m, 'pricing') and m.pricing:
                    price = f"  ${m.pricing.get('prompt', '?')}/{m.pricing.get('completion', '?')} /1M"
                results.append(f"  {m.id}{price}" if pricing else m.id)
            if pricing:
                print(f"Models ({len(results)}):")
            for line in results:
                print(line)
            return results
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            return []

    def generate(
        self,
        prompt: str,
        model: Optional[str] = None,
        system: Optional[str] = None,
        stream: bool = True,
        images: Optional[list] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        web_search: bool = False,
        json_mode: bool = False,
        reasoning: Optional[str] = None,
        fallbacks: Optional[list] = None,
    ) -> dict:
        """Send a prompt to a model and return the response."""
        model = model or _DEFAULT_MODEL
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
                    url = encode_image(p)
                    content.append({"type": "image_url", "image_url": {"url": url}})
                msgs.append({"role": "user", "content": content})
            else:
                msgs.append({"role": "user", "content": prompt})

            params: dict = {"model": model, "messages": msgs, "stream": stream}
            if temperature is not None:
                params["temperature"] = temperature
            if max_tokens:
                params["max_tokens"] = max_tokens
            if json_mode:
                params["response_format"] = {"type": "json_object"}

            extra: dict = {}
            if reasoning:
                extra["reasoning"] = {"effort": reasoning}
            if web_search:
                extra["plugins"] = [{"id": "web"}]
            if fallbacks:
                extra["models"] = [model] + [resolve_model(m) for m in fallbacks]
            if extra:
                params["extra_body"] = extra

            t0 = time.time()
            if stream:
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


def fan_out(
    client: OpenRouterClient,
    prompt: str,
    aliases: list,
    system: Optional[str] = None,
    images: Optional[list] = None,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None,
    web_search: bool = False,
    json_mode: bool = False,
    reasoning: Optional[str] = None,
    output_dir: Optional[str] = None,
    verbose: bool = False,
) -> dict:
    """Send prompt to multiple models in parallel, collect results."""
    results = {}

    def query_model(alias: str) -> tuple:
        model = resolve_model(alias)
        if verbose:
            print(f"  Querying {alias} ({model})...", file=sys.stderr)
        result = client.generate(
            prompt=prompt, model=model, system=system, images=images,
            temperature=temperature, max_tokens=max_tokens,
            web_search=web_search, json_mode=json_mode,
            reasoning=reasoning, stream=False,
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
        print(f"  {alias.upper()} ({_MODEL_ALIASES.get(alias, alias)})")
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


def synthesize(
    client: OpenRouterClient,
    prompt: str,
    results: dict,
    model: Optional[str] = None,
    verbose: bool = False,
) -> Optional[str]:
    """Synthesize fan-out results into a single consensus answer."""
    successful = {a: r for a, r in results.items() if r.get('ok')}
    if len(successful) < 2:
        print("Error: Need at least 2 successful responses to synthesize", file=sys.stderr)
        return None

    responses_text = ""
    for alias, result in successful.items():
        responses_text += f"\n### {alias.upper()} ({_MODEL_ALIASES.get(alias, alias)})\n"
        responses_text += result['content'] + "\n"

    synthesis_input = SYNTHESIS_PROMPT.format(
        count=len(successful),
        prompt=prompt,
        responses=responses_text,
    )

    _ensure_panel()
    synth_model = resolve_model(model) if model else _DEFAULT_MODEL
    if verbose:
        print(f"\nSynthesizing with {synth_model}...", file=sys.stderr)

    print(f"\n{'='*60}")
    print(f"  SYNTHESIS ({synth_model})")
    print(f"{'='*60}\n")

    result = client.generate(prompt=synthesis_input, model=synth_model, stream=True)
    return result.get('content') if result['ok'] else None


def show_panel() -> None:
    """Display the current expert panel."""
    config = _panel_path()
    source = "expert-panel.json" if config.exists() else "built-in defaults"
    _ensure_panel()
    enabled = get_enabled(_PANEL)
    disabled = [e for e in _PANEL if not e.get('enabled', True)]

    print(f"Expert Panel ({len(enabled)} active, from {source}):\n")
    w = max(len(e['alias']) for e in _PANEL)
    for e in enabled:
        print(f"  {e['alias']:<{w+2}} {e['model']:<40} {e.get('strength', '')}")
    if disabled:
        print(f"\nDisabled ({len(disabled)}):")
        for e in disabled:
            print(f"  {e['alias']:<{w+2}} {e['model']}")
    print(f"\nConfig: {config}")


def init_panel() -> None:
    """Generate a fresh expert-panel.json from bootstrap template."""
    config = _panel_path()
    if config.exists():
        print(f"expert-panel.json already exists at {config}", file=sys.stderr)
        print("Delete it first to regenerate, or edit it directly.", file=sys.stderr)
        sys.exit(1)
    # Bootstrap template — edit expert-panel.json after generation, not this code.
    template = [
        {"alias": "claude",   "model": "anthropic/claude-opus-4.6",      "enabled": True,  "provider": "Anthropic", "strength": "Deepest reasoning, edge cases"},
        {"alias": "gpt",      "model": "openai/gpt-5.2",                 "enabled": True,  "provider": "OpenAI",    "strength": "Strong all-round, structured output"},
        {"alias": "gemini",   "model": "google/gemini-3-pro-preview",     "enabled": True,  "provider": "Google",    "strength": "Creative connections, multimodal"},
        {"alias": "deepseek", "model": "deepseek/deepseek-r1",            "enabled": True,  "provider": "DeepSeek",  "strength": "Best open-source reasoning"},
        {"alias": "grok",     "model": "x-ai/grok-4",                    "enabled": True,  "provider": "xAI",       "strength": "Contrarian, evidence citations"},
        {"alias": "llama",    "model": "meta-llama/llama-4-maverick",     "enabled": False, "provider": "Meta",      "strength": "128-expert MoE, multimodal"},
        {"alias": "kimi",     "model": "moonshotai/kimi-k2.5",           "enabled": False, "provider": "Moonshot",  "strength": "Best value, deep domain knowledge"},
        {"alias": "glm",      "model": "z-ai/glm-5",                     "enabled": False, "provider": "ZHIPU",     "strength": "Factual accuracy, catches errors"},
        {"alias": "qwen",     "model": "qwen/qwen3.5-397b-a17b",         "enabled": False, "provider": "Alibaba",   "strength": "Native multimodal, 201 languages"},
    ]
    with open(config, 'w') as f:
        json.dump(template, f, indent=2)
        f.write('\n')
    print(f"Created {config}")
    print(f"  {len(template)} models ({sum(1 for t in template if t['enabled'])} enabled). Edit to customize.")


def main():
    p = argparse.ArgumentParser(
        description="Query the world's best AI models from your terminal",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  openrouter "Explain quantum computing" -m anthropic/claude-opus-4.6
  openrouter --all "Compare React vs Svelte"
  openrouter --all --synthesize "Best practices for error handling"
  openrouter --panel                         # Show expert team
  openrouter --init-panel                    # Generate expert-panel.json
  openrouter --list-models anthropic --pricing

Aliases and variants are configured in expert-panel.json.
Run --panel to see the current team.
""")

    p.add_argument('prompt', nargs='?', help='Prompt (or pipe via stdin)')
    p.add_argument('--file', '-f', help='Load prompt from file')
    p.add_argument('--model', '-m', default=None, help='Model ID or alias from expert-panel.json')
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
    p.add_argument('--synthesize', action='store_true', help='Synthesize fan-out into consensus (use with --all)')
    p.add_argument('--synth-model', default=None, help='Model for synthesis (default: first enabled)')
    p.add_argument('--init-panel', action='store_true', help='Generate expert-panel.json')

    args = p.parse_args()

    # ── Info commands (no API key needed) ──

    if args.init_panel:
        init_panel()
        return

    if args.panel:
        show_panel()
        return

    if args.aliases:
        print("Model aliases:")
        _ensure_panel()
        w = max(len(a) for a in _MODEL_ALIASES)
        for alias, mid in sorted(_MODEL_ALIASES.items()):
            print(f"  {alias:<{w + 2}} -> {mid}")
        print("\nVariants (append with colon, e.g. claude:online):")
        for name in sorted(MODEL_VARIANTS):
            print(f"  :{name}")
        return

    if args.list_models is not None:
        OpenRouterClient().list_models(pricing=args.pricing, filter_str=args.list_models or None)
        return

    # ── Resolve prompt ──

    prompt = args.prompt
    if not prompt and args.file:
        fp = Path(args.file)
        if not fp.exists():
            print(f"Error: {fp} not found", file=sys.stderr)
            sys.exit(1)
        prompt = fp.read_text().strip()
    elif not prompt and not sys.stdin.isatty():
        prompt = sys.stdin.read().strip()

    if not prompt:
        p.print_help()
        sys.exit(1)

    client = OpenRouterClient()

    # ── Fan-out mode ──

    if args.all:
        _ensure_panel()
        enabled = get_enabled_aliases(_PANEL)
        if not enabled:
            print("Error: No models enabled in panel. Run --panel to check.", file=sys.stderr)
            sys.exit(1)
        output_dir = args.output
        if output_dir:
            Path(output_dir).mkdir(parents=True, exist_ok=True)
        print(f"Querying {len(enabled)} models: {', '.join(enabled)}", file=sys.stderr)
        results = fan_out(
            client, prompt, enabled, system=args.system, images=args.images,
            temperature=args.temperature, max_tokens=args.max_tokens,
            web_search=args.web, json_mode=args.json_mode,
            reasoning=args.reasoning, output_dir=output_dir, verbose=args.verbose,
        )
        if args.synthesize:
            content = synthesize(client, prompt, results, model=args.synth_model, verbose=args.verbose)
            if content and output_dir:
                out = Path(output_dir) / "synthesis.md"
                out.write_text(content)
                print(f"\nSaved synthesis: {out}", file=sys.stderr)
        return

    # ── Single model mode ──

    _ensure_panel()
    model = resolve_model(args.model) if args.model else _DEFAULT_MODEL
    stream = not args.no_stream

    if args.verbose:
        parts = [f"Model: {model}"]
        if args.web:
            parts.append("Web: on")
        print(" | ".join(parts), file=sys.stderr)

    result = client.generate(
        prompt=prompt, model=model, system=args.system,
        images=args.images, temperature=args.temperature,
        max_tokens=args.max_tokens, web_search=args.web,
        json_mode=args.json_mode, reasoning=args.reasoning,
        fallbacks=args.fallback, stream=stream,
    )

    if not result['ok']:
        print(f"Error: {result['error']}", file=sys.stderr)
        sys.exit(1)

    if not stream:
        print(result['content'])

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(result['content'])
        print(f"Saved: {args.output}", file=sys.stderr)

    if args.verbose:
        parts = [f"Time: {result.get('time', 0)}s"]
        if result.get('tokens'):
            parts.append(f"Tokens: {result['tokens']}")
        if result.get('cost') is not None:
            parts.append(f"Cost: ${result['cost']:.4f}")
        print(" | ".join(parts), file=sys.stderr)


if __name__ == "__main__":
    main()
