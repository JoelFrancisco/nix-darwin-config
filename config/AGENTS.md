# Global agent instructions

- Preserve unrelated work and inspect a worktree before editing it.
- Use project-local instructions when they exist; they override this file.
- Never print, commit, or copy credentials, auth databases, histories, or session state.
- Prefer small, verifiable changes. Run the narrow checks first and the full suite before handing off.
- Use `rg`/`rg --files` for local search, `apply_patch` for intentional edits, and non-interactive Git commands.
- Treat services, deployments, messages, purchases, and destructive actions as external state changes that require clear user intent.
- Project development environments belong in each repository's `devenv.nix`; do not grow the global machine profile for one project.

