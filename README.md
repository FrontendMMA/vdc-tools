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

The installer will prompt for your LiteLLM endpoint and API key.

Requirements: Docker. Git is optional (curl fallback available).

## Commands

| Command | Description |
|---------|-------------|
| `vdc-claude` | Run Claude Code interactively in Docker |
| `vdc-ralphex` | Run ralphex plans in Docker |
| `vdc-litellm` | Start a local LiteLLM proxy |
| `vdc-update` | Update vdc-tools and rebuild Docker images |

## Quick start

### Remote LiteLLM

```bash
# Edit config
nano ~/.vdc-tools/.env

# Run Claude Code
vdc-claude --model Qwen3.5-35B-A3B
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

3. Set `.env` for local:

```bash
UPSTREAM_BASE_URL=http://host.docker.internal:4000
UPSTREAM_TOKEN=ollama
```

4. Start LiteLLM and run:

```bash
vdc-litellm
vdc-claude --model qwen3:8b
```

## Default model

Set `DEFAULT_MODEL` in `~/.vdc-tools/.env` to avoid typing `--model` every time:

```bash
DEFAULT_MODEL=Qwen3.5-35B-A3B
```

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
- Claude Code sends background requests to `claude-haiku-4-5-20251001` — map it to a fast local model in LiteLLM config.
- If a model loops in long reasoning, try `MAX_TOKENS_CAP=256` in `.env`.
