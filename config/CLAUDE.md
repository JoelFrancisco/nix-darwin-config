# Global Claude instructions

Read project-local `CLAUDE.md` and `AGENTS.md` files before acting. Keep the main loop focused on decisions, integration, and review; delegate bounded mechanical work when useful. Return conclusions instead of raw dumps.

## Working agreement

- Preserve user changes and inspect Git state before editing.
- Prefer the smallest complete implementation and verify it in proportion to risk.
- Never expose or commit credentials, auth state, histories, databases, or session files.
- Use the local executor MCP for isolated delegated commands and the ai-memory MCP at `http://127.0.0.1:49374/mcp` for durable memory.
- Use project-local `devenv` environments for language runtimes and service dependencies.
- Ask before actions that affect external systems or people unless the request explicitly authorizes them.

## Models

Use the strongest available model for architecture, integration, and review. Use cheaper/faster models for clear mechanical tasks. Escalate when the result does not meet the bar; judge output rather than provider branding.

