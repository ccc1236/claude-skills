# claude-skills

Personal [Claude Code](https://claude.com/claude-code) skills, packaged as a plugin
marketplace. One plugin per skill.

## Install
```bash
claude plugin marketplace add ccc1236/claude-skills
claude plugin install <skill>@claude-skills
```

## Skills
| Plugin | What it does |
|--------|--------------|
| [`ship-audit`](plugins/ship-audit/) | Security and robustness audit for an app before or after you ship it: self-hosted tools, VPS/homelab services, and apps on managed platforms (Supabase, Vercel, Firebase, Netlify). |

## Layout
```
claude-skills/
├── .claude-plugin/marketplace.json     # lists every plugin
└── plugins/<skill>/
    ├── .claude-plugin/plugin.json      # name, version, description
    └── skills/<skill>/SKILL.md         # the skill (+ references/)
```

## Adding a skill
1. Create `plugins/<skill>/` with `.claude-plugin/plugin.json` and `skills/<skill>/SKILL.md`.
2. Add an entry to `.claude-plugin/marketplace.json`.
3. Bump `version` in `plugin.json` when you change an existing skill, so installs pick up the update.

## Secret hygiene
gitleaks runs as a local pre-commit hook (`pip install pre-commit && pre-commit install`)
and in CI on every push and PR.
