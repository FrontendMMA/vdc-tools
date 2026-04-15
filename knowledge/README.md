# Knowledge base

Put your reusable notes, specs, checklists, prompts, and playbooks here.

This directory is mounted into every Claude runner container as:

- `/knowledge` (read-only)

The launcher also starts Claude Code with:

- `--add-dir /knowledge`

That means inside Claude Code you can refer to files directly, for example:

- `/knowledge/architecture/ssr.md`
- `/knowledge/checklists/release.md`
- `/knowledge/prompts/review.md`
