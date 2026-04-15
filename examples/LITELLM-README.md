# LiteLLM local setup

This directory contains a starter config for running LiteLLM locally in front of Ollama.

Suggested flow:

1. Install LiteLLM into `~/.vdc-tools/state/litellm-venv`
2. Copy `litellm.config.example.yaml` to `litellm.config.yaml`
3. Adjust the Ollama model tags to match what is installed locally
4. Start LiteLLM with `vdc-litellm`
5. Point `~/.vdc-tools/.env` to `http://host.docker.internal:4000`

Example install:

```bash
python3.11 -m venv ~/.vdc-tools/state/litellm-venv
~/.vdc-tools/state/litellm-venv/bin/pip install 'litellm[proxy]'
cp ~/.vdc-tools/state/litellm.config.example.yaml ~/.vdc-tools/state/litellm.config.yaml
vdc-litellm
```
