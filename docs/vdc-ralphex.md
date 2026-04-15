# vdc-ralphex

Выполнение планов реализации через ralphex в Docker-контейнере.

## Использование

```bash
# Один план
vdc-ralphex [опции] <план.md> [аргументы ralphex...]

# Все планы (batch)
vdc-ralphex [опции] all [app-slug] [аргументы run-all-plans...]
```

## Флаги

| Флаг | Описание |
|------|----------|
| `--model NAME` | Модель для использования |
| `--project-dir PATH` | Директория проекта |
| `--print-config` | Показать пути и выйти |
| `-h`, `--help` | Справка |

## Single-режим

Выполняет один план — файл `.md` с описанием задач.

```bash
# Полное выполнение плана
vdc-ralphex docs/plans/feature.md

# Только задачи, без review
vdc-ralphex docs/plans/feature.md --tasks-only

# Только review
vdc-ralphex docs/plans/feature.md --review
```

Аргументы после пути к файлу передаются напрямую в ralphex.

## Batch-режим

Ключевое слово `all` запускает пакетное выполнение всех незавершённых планов.

```bash
# Все незавершённые планы из docs/plans/
vdc-ralphex all

# Планы для конкретного приложения (из .gen/<app-slug>/state.json)
vdc-ralphex all demo-site

# Без внешнего review (Codex)
vdc-ralphex all --no-external

# Быстрый режим (только задачи, без review)
vdc-ralphex all --fast

# Комбинация
vdc-ralphex all demo-site --fast --no-external
```

### Аргументы batch-режима

| Аргумент | Описание |
|----------|----------|
| `app-slug` | Первый аргумент без `--` — slug приложения из `.gen/` |
| `--fast` | Только задачи, без review |
| `--review` | Только review |
| `--external` | Только внешний review |
| `--no-external` | Отключить внешний (Codex) review |
| `--force` | Игнорировать маркеры завершённых планов |
| `--mark-completed` | Всегда создавать маркеры завершения |
| `--no-mark-completed` | Не создавать маркеры завершения |

### Маркеры завершения

Завершённые планы помечаются файлами в `docs/plans/completed/`. При повторном запуске они пропускаются (если не указан `--force`).

## Примеры

```bash
# Выполнить один план с конкретной моделью
vdc-ralphex docs/plans/auth.md --model Qwen3.5-35B-A3B

# Пакетно выполнить все планы для приложения
vdc-ralphex all my-app

# Быстрый прогон без review и external
vdc-ralphex all my-app --fast --no-external
```
