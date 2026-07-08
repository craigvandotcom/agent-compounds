# Stack detection — project-command auto-detect fallback

Read this only when the project is not the registry-standard Next.js/pnpm stack —
i.e. `AGENTS.md` is missing or has no usable `Project Commands` section. Probe the
project root, then map what you find to `CMD_TEST` / `CMD_LINT` / `CMD_TYPECHECK` /
`CMD_BUILD` / `CMD_FORMAT` / `CMD_QUALITY`.

```bash
if [ -f "package.json" ]; then
  if [ -f "pnpm-lock.yaml" ]; then PKG="pnpm"
  elif [ -f "yarn.lock" ]; then PKG="yarn"
  elif [ -f "bun.lockb" ]; then PKG="bun"
  else PKG="npm"; fi
  echo "Available scripts:"
  grep -E '^\s+"[^"]+":' package.json | head -20
fi

if [ -f "Cargo.toml" ]; then echo "Rust: cargo test, cargo clippy, cargo build"; fi
if [ -f "Makefile" ]; then echo "Makefile targets:"; grep -E '^[a-zA-Z_-]+:' Makefile | head -10; fi
if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then echo "Python project"; fi
if [ -f "go.mod" ]; then echo "Go: go test ./..., go vet, go build"; fi
```
