# Global Claude instructions

Read project-local `CLAUDE.md` and `AGENTS.md` files before acting. Local instructions override this file. Preserve unrelated user work and inspect Git state before editing.

## Model routing

Keep the main loop focused on planning, decisions, integration, and review. Delegate bounded mechanical work when useful, and return conclusions instead of raw dumps, logs, or screenshots.

- Use the strongest available reasoning model for architecture, ambiguous debugging, integration, and final review.
- Use fast/low-cost models for clear mechanical edits, searches, and data collection where a wrong answer is cheap.
- Anything user-facing—UI, copy, or API design—needs strong taste as well as correctness.
- Escalate when a delegated result does not meet the bar. Judge the output, not the provider name or price.
- Prefer one decisive high-effort verification step over running an entire fleet at maximum effort.

Codex models are reached through the Codex CLI. For isolated implementation, investigation, or an independent review, give Codex a self-contained prompt and an explicit sandbox. Claude agents can be used directly for judgment-heavy work. Browser/UI verification belongs in a real browser session.

## Working agreement

- Prefer the smallest complete implementation and verify it in proportion to risk.
- Search with `rg`/`rg --files`; use intentional patches; avoid destructive Git operations.
- Run narrow checks while working, then the relevant full suite before handoff.
- Never expose or commit credentials, auth state, histories, databases, or session files.
- Ask before actions that affect external systems or people unless the request explicitly authorizes them.
- Project language runtimes and service dependencies belong in each repository's `devenv`, not the global machine profile.

## Local agent infrastructure

- The Executor MCP runs locally through `executor mcp`; its daemon is bound to `127.0.0.1:4789`.
- The ai-memory MCP endpoint is `http://127.0.0.1:49374/mcp`.
- Use `claudex` when Claude should route through the loopback CLIProxyAPI gateway; use `jclaudex` for its ai-jail form.
- `jclaude`, `jcodex`, and `jopencode` keep SSH and `~/Work` available while masking common credential files.
- Skills are installed only from the public Matt Pocock and JoelFrancisco allow-lists. Do not discover or install employer-specific skills from local/private sources.

## Execution hygiene

Subagent prompts must be self-contained: state the goal, scope, constraints, output contract, and checks. A delegated task should be independently useful and have one owner. Review delegated output before integrating it.

Prefer reversible operations. When a command changes persistent state, resolve the exact target first. Do not broaden permissions, expose a service beyond loopback, or place runtime secrets in a Nix expression or generated store path.
