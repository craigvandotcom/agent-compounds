# The Robot-Mode Maker

Design and implement a "robot mode" CLI for this project.

The CLI should be optimized for use by AI coding agents:

1. **JSON Output**: Add --json flag to every command for machine-readable output
2. **Quick Start**: Running with no args shows help in ~100 tokens
3. **Structured Errors**: Error responses include code, message, suggestions
4. **TTY Detection**: Auto-switch to JSON when piped
5. **Exit Codes**: Meaningful codes (0=success, 1=not found, 2=invalid args, etc.)
6. **Token Efficient**: Dense, minimal output that respects context limits

Think about what information an AI agent would need and how to present it most efficiently.

Design the interface before implementing.
