# vdc-litellm

Запуск локального LiteLLM-прокси для работы с Ollama и другими LLM-бэкендами.

## Использование

```bash
vdc-litellm [--config PATH] [--host HOST] [--port PORT] [--debug]
```

## Флаги

| Флаг | Описание | По умолчанию |
|------|----------|-------------|
| `--config PATH` | Путь к конфигу LiteLLM | `~/.vdc-tools/state/litellm.config.yaml` |
| `--host HOST` | Адрес привязки | `127.0.0.1` |
| `--port PORT` | Порт | `4000` |
| `--debug` | Подробное логирование | выключено |
| `-h`, `--help` | Справка | — |

Флаги можно также задать через переменные окружения: `LITELLM_CONFIG`, `LITELLM_HOST`, `LITELLM_PORT`, `LITELLM_DEBUG`.

## Установка LiteLLM

LiteLLM нужно установить отдельно:

```bash
python3.11 -m venv ~/.vdc-tools/state/litellm-venv
~/.vdc-tools/state/litellm-venv/bin/pip install 'litellm[proxy]'
```

Скрипт автоматически найдёт `litellm` в PATH или в `~/.vdc-tools/state/litellm-venv/bin/`.

## Настройка конфига

Скопируйте пример и отредактируйте:

```bash
cp ~/.vdc-tools/state/litellm.config.example.yaml ~/.vdc-tools/state/litellm.config.yaml
```

Формат конфига:

```yaml
model_list:
  # Claude Code отправляет фоновые запросы на эту модель —
  # подойдёт быстрая текстовая модель
  - model_name: claude-haiku-4-5-20251001
    litellm_params:
      model: ollama/llama3:latest
      api_base: http://127.0.0.1:11434

  # Основная модель для интерактивной работы
  - model_name: qwen3:8b
    litellm_params:
      model: ollama/qwen3:8b
      api_base: http://127.0.0.1:11434

litellm_settings:
  master_key: ollama
```

## Полный сценарий: Ollama + LiteLLM + vdc-claude

1. Убедитесь, что Ollama запущен и модели скачаны:

```bash
ollama pull qwen3:8b
ollama pull llama3:latest
```

2. Настройте `.env`:

```bash
UPSTREAM_BASE_URL=http://host.docker.internal:4000
UPSTREAM_TOKEN=ollama
DEFAULT_MODEL=qwen3:8b
```

3. Запустите LiteLLM:

```bash
vdc-litellm
```

4. В другом терминале запустите Claude Code:

```bash
vdc-claude
```

## Примеры

```bash
# Запуск с дефолтными настройками
vdc-litellm

# Запуск на другом порту с debug-логами
vdc-litellm --port 5000 --debug

# Запуск с кастомным конфигом
vdc-litellm --config /path/to/my-config.yaml
```
