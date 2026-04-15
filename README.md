# vdc-tools

Run Claude Code in Docker with local/remote LLMs via LiteLLM.

- Project-scoped memory and config isolation
- Shared read-only knowledge base
- MCP support (Figma, Chrome DevTools, etc.)
- Compatibility proxy for LiteLLM / Ollama backends
- Batch plan execution via ralphex
- YOLO mode

## Install

```bash
curl -sL https://raw.githubusercontent.com/FrontendMMA/vdc-tools/main/install.sh | bash
```

Then configure your LLM backend:

```bash
vdc-setup
```

Requirements: Docker. Git is optional (curl fallback available).

## Commands

| Command | Description |
|---------|-------------|
| `vdc-claude` | Run Claude Code interactively in Docker |
| `vdc-setup` | Configure LLM backend (URL, token, model) |
| `vdc-ralphex` | Run ralphex plans in Docker |
| `vdc-litellm` | Start a local LiteLLM proxy |
| `vdc-update` | Update vdc-tools and rebuild Docker images |

All commands support `--version` / `-V`.

## Quick start

### Remote LiteLLM

```bash
# Configure (interactive wizard)
vdc-setup

# Run Claude Code
vdc-claude
```

### Local LiteLLM + Ollama

1. Install LiteLLM:

```bash
python3.11 -m venv ~/.vdc-tools/state/litellm-venv
~/.vdc-tools/state/litellm-venv/bin/pip install 'litellm[proxy]'
```

2. Copy and edit config:

```bash
cp ~/.vdc-tools/state/litellm.config.example.yaml ~/.vdc-tools/state/litellm.config.yaml
```

3. Configure for local:

```bash
vdc-setup
# Set UPSTREAM_BASE_URL to http://host.docker.internal:4000
# Set UPSTREAM_TOKEN to ollama
```

4. Start LiteLLM and run:

```bash
vdc-litellm
vdc-claude --model qwen3:8b
```

## Models

Set in `~/.vdc-tools/.env` or via `vdc-setup`:

```bash
DEFAULT_MODEL=Qwen3.5-35B-A3B       # main model (used with --model)
SMALL_FAST_MODEL=qwen3:8b            # fast model for background requests
```

Claude Code sends background requests (tab completion, file summaries) to `claude-haiku-4-5-20251001`. Set `SMALL_FAST_MODEL` to map these to a fast local model.

## Usage

```bash
# Interactive Claude Code
vdc-claude
vdc-claude --model qwen3:8b
vdc-claude --yolo
vdc-claude --continue
vdc-claude --resume

# Single plan with ralphex
vdc-ralphex docs/plans/feature.md
vdc-ralphex docs/plans/feature.md --tasks-only

# Batch: all plans
vdc-ralphex all
vdc-ralphex all --no-external
vdc-ralphex all --fast

# Batch: plans for a specific app
vdc-ralphex all my-app
vdc-ralphex all my-app --no-external
```

## Figma MCP

`figma-developer-mcp` is pre-installed in the Docker image. To enable:

1. Get a Personal Access Token: `figma.com` > Settings > Personal Access Tokens.
2. Create `~/.vdc-tools/mcp/mcp.json`:

```json
{
  "mcpServers": {
    "figma": {
      "type": "stdio",
      "command": "figma-developer-mcp",
      "args": ["--stdio"],
      "env": {
        "FIGMA_API_KEY": "figd_YOUR_TOKEN"
      }
    }
  }
}
```

3. Restart `vdc-claude`.

## Project isolation

Each project gets its own config directory:

```
~/.vdc-tools/projects/<project-id>/
  claude-config/     # Claude Code memory, settings, sessions
  ralphex-config/    # ralphex config (per-project)
```

Project ID is a stable hash of the project path. Git repo root is used when available.

## Shared knowledge base

```
~/.vdc-tools/knowledge/
```

Mounted read-only as `/knowledge`. Claude starts with `--add-dir /knowledge`.

## Runner image tools

The Docker image includes:

- bash, git, curl, wget, jq
- ripgrep, fd, findutils, grep, sed
- python3, pip, gcc, g++, make
- node, npm, pnpm
- Chromium (for browser MCP)
- figma-developer-mcp (pre-installed)
- ralphex (pre-installed)

## Architecture

```
vdc-claude / vdc-ralphex
    |
    v
[Proxy container]  -- sanitizes requests, caps tokens
    |
    v
[LiteLLM]          -- local or remote
    |
    v
[Ollama / OpenAI / any LLM provider]
```

## Notes on local models

- `qwen3`-family models work better for tool-use than `llama3`.
- Set `SMALL_FAST_MODEL` for background requests (see [Models](#models) section).
- If a model loops in long reasoning, try `MAX_TOKENS_CAP=256` in `.env`.
