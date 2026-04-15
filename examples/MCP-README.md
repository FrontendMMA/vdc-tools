# MCP configuration

Put your active config in `~/.vdc-tools/mcp/mcp.json`.

The launcher automatically adds:

- `--mcp-config /mcp/mcp.json` when that file exists
- `/mcp` mount into the runner container

## Figma MCP

`figma-developer-mcp` is pre-installed in the Docker image. No npx needed.

1. Get a Personal Access Token at `figma.com` > Settings > Personal Access Tokens.

2. Create `~/.vdc-tools/mcp/mcp.json`:

```json
{
  "mcpServers": {
    "figma": {
      "type": "stdio",
      "command": "figma-developer-mcp",
      "args": ["--stdio"],
      "env": {
        "FIGMA_API_KEY": "figd_YOUR_TOKEN_HERE"
      }
    }
  }
}
```

3. Restart `vdc-claude` — Figma tools will appear automatically.

## Chrome DevTools MCP

Also available in `mcp.json.example`. The runner image includes Chromium at `/usr/bin/chromium`.

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"],
      "env": {
        "CHROME_PATH": "/usr/bin/chromium"
      }
    }
  }
}
```

## Multiple servers

Combine entries under `mcpServers` in a single `mcp.json`:

```json
{
  "mcpServers": {
    "figma": { ... },
    "chrome-devtools": { ... }
  }
}
```
