# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is vdc-tools

Containerized CLI tool that runs Claude Code in Docker with local/remote LLM backends via LiteLLM. Provides project-scoped isolation, shared knowledge base, MCP integrations (Figma, Chrome DevTools), and batch plan execution via ralphex.

## Install & Build

```bash
curl -sL https://raw.githubusercontent.com/FrontendMMA/vdc-tools/main/install.sh | bash

# Docker images are built automatically on first run via docker-compose
# To force rebuild:
docker compose build --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g)
```

There are no tests or linters configured in this project.

## Architecture

```
bin/                  # Bash CLI entry points (vdc-claude, vdc-ralphex, vdc-litellm, vdc-update)
proxy/                # Express API proxy (server.js) — sanitizes requests, caps tokens, forwards to upstream LLM
claude-runner/        # Dockerfile for the Claude CLI container (includes system tools, ralphex, Chromium)
install.sh            # Unified bash installer — creates ~/.vdc-tools/ structure, symlinks, interactive .env setup
examples/             # MCP and LiteLLM config examples
knowledge/            # Shared read-only knowledge base template
```

Two Docker services defined in `docker-compose.yml`:
- **proxy** — Express server (port 8080) that sanitizes and forwards API requests
- **claude-runner** — Container with Claude CLI, full dev tooling, and ralphex

## Runtime data layout

```
~/.vdc-tools/
├── src/                          # Clone of the repository
├── .env                          # UPSTREAM_BASE_URL, UPSTREAM_TOKEN, DEFAULT_MODEL, etc.
├── projects/<hash>/              # Per-project isolation (hash of project path, uses git root)
│   ├── claude-config/            # Claude Code settings, memory, sessions
│   └── ralphex-config/           # ralphex settings
├── knowledge/                    # Mounted read-only as /knowledge in containers
├── mcp/                          # MCP server configs (mcp.json)
└── state/                        # LiteLLM config & venv
```

## Key conventions

- All bash scripts use `set -euo pipefail`
- Project ID is a stable hash of the absolute project path (git root when available)
- Docker containers match host UID/GID for file ownership compatibility
- Proxy strips unsupported fields from requests (thinking, context_management, MCP servers) — controlled by `STRIP_*` env vars
- `settings.json` generated per-project includes security deny rules blocking `.env`, credentials, and key files
