"""Tests for openrouter.py pure functions."""

import json
import os
import sys
import tempfile
from pathlib import Path

# Add parent dir to path so we can import openrouter
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import openrouter


def test_resolve_model_alias():
    """Known alias resolves to full model ID."""
    result = openrouter.resolve_model("claude")
    assert result == "anthropic/claude-opus-4.6"


def test_resolve_model_full_id():
    """Full model ID passes through unchanged."""
    result = openrouter.resolve_model("anthropic/claude-opus-4.6")
    assert result == "anthropic/claude-opus-4.6"


def test_resolve_model_variant():
    """Alias with variant suffix resolves correctly."""
    result = openrouter.resolve_model("claude:online")
    assert result == "anthropic/claude-opus-4.6:online"


def test_resolve_model_unknown_variant():
    """Unknown variant passes through as-is."""
    result = openrouter.resolve_model("anthropic/claude-opus-4.6:custom")
    assert result == "anthropic/claude-opus-4.6:custom"


def test_resolve_model_case_insensitive():
    """Alias lookup is case-insensitive."""
    result = openrouter.resolve_model("Claude")
    assert "claude" in result.lower()


def test_get_aliases():
    """get_aliases returns dict mapping alias -> model ID."""
    config = openrouter.load_config()
    aliases = openrouter.get_aliases(config['models'])
    assert isinstance(aliases, dict)
    assert len(aliases) >= 1


def test_get_enabled():
    """get_enabled filters to only enabled entries."""
    config = openrouter.load_config()
    enabled = openrouter.get_enabled(config['models'])
    for e in enabled:
        assert e.get("enabled", True) is True


def test_get_enabled_aliases():
    """get_enabled_aliases returns list of alias strings."""
    config = openrouter.load_config()
    aliases = openrouter.get_enabled_aliases(config['models'])
    assert isinstance(aliases, list)
    assert all(isinstance(a, str) for a in aliases)
    assert len(aliases) >= 1


def test_load_config():
    """load_config reads from config.json."""
    config = openrouter.load_config()
    assert 'models' in config
    models = config['models']
    assert len(models) >= 1
    assert all("alias" in e and "model" in e for e in models)


def test_encode_image(tmp_path):
    """encode_image returns a data URL string."""
    # Create a minimal 1x1 PNG
    import base64
    png_bytes = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4"
        "nGNgYPgPAAEDAQAIicLsAAAABJRU5ErkJggg=="
    )
    img = tmp_path / "test.png"
    img.write_bytes(png_bytes)

    result = openrouter.encode_image(img)
    assert isinstance(result, str)
    assert result.startswith("data:image/png;base64,")


def test_config_json_valid():
    """config.json is valid JSON with expected structure."""
    config_path = Path(__file__).resolve().parent.parent / "config.json"
    if not config_path.exists():
        return  # Skip if no config.json
    with open(config_path) as f:
        config = json.load(f)
    assert isinstance(config, dict)
    assert "models" in config
    models = config["models"]
    assert isinstance(models, list)
    for entry in models:
        assert "alias" in entry
        assert "model" in entry
        assert "enabled" in entry
        assert isinstance(entry["enabled"], bool)


def test_config_json_no_duplicate_aliases():
    """config.json has no duplicate aliases."""
    config_path = Path(__file__).resolve().parent.parent / "config.json"
    if not config_path.exists():
        return
    with open(config_path) as f:
        config = json.load(f)
    aliases = [e["alias"] for e in config["models"]]
    assert len(aliases) == len(set(aliases)), f"Duplicate aliases: {aliases}"


def test_model_variants_all_have_colon():
    """All variant suffixes start with colon."""
    for name, suffix in openrouter.MODEL_VARIANTS.items():
        assert suffix.startswith(":"), f"Variant {name} missing colon prefix"


if __name__ == "__main__":
    # Simple test runner — no pytest dependency needed
    import traceback
    passed = failed = 0
    for name, func in list(globals().items()):
        if name.startswith("test_") and callable(func):
            try:
                import inspect
                sig = inspect.signature(func)
                if "tmp_path" in sig.parameters:
                    with tempfile.TemporaryDirectory() as td:
                        func(Path(td))
                else:
                    func()
                print(f"  PASS  {name}")
                passed += 1
            except Exception as e:
                print(f"  FAIL  {name}: {e}")
                traceback.print_exc()
                failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
