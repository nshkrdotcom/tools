# Repository Guidelines

## Project Structure & Module Organization
This toolkit is a lightweight Elixir Mix project. The entry point `run.exs` orchestrates scanning, filtering, and action execution. Individual automation scripts live in `actions/`, each defining an `Actions.*` module with a `run/1` function. Repository manifests (`repos.json`, `repos_exclude.json`, `repos_filtered.json`) are regenerated in the project root and should be kept out of version control. Shared formatter options reside in `.formatter.exs`, while `README.md` and `QUICKSTART.md` describe workflows and future enhancements.

## Build, Test, and Development Commands
- `mix deps.get` installs Hex packages referenced in `mix.exs`.
- `mix format` applies the repo-standard formatter configuration to all `.exs` scripts.
- `elixir run.exs scan` discovers Elixir repositories in the parent directory.
- `elixir run.exs filter` rebuilds the filtered repository set after adjusting exclusions.
- `elixir run.exs uncommitted` checks each filtered repo for pending changes; pair with `elixir run.exs setup` to rebuild inputs before running actions.

## Coding Style & Naming Conventions
Follow idiomatic Elixir style with two-space indentation and one module per file. Action files use `snake_case` names (for example, `actions/check_uncommitted.exs`) and define PascalCase modules (`Actions.CheckUncommitted`). Prefer pattern matching and pipelines for clarity, and document non-obvious logic with concise comments. Use `mix format` before committing to avoid formatter drift.

## Testing Guidelines
The project does not yet ship automated tests; new features should include targeted `*_test.exs` files under a `test/` directory. Use `mix test` locally and `mix test --cover` when measuring coverage; keep new modules covered by deterministic unit tests that stub filesystem or network calls. When adding integration flows, capture representative fixture data so tests stay hermetic.

## Commit & Pull Request Guidelines
Recent history shows short, descriptive subjects (`Rewrite tool in Elixir with comprehensive documentation`). Keep subject lines in imperative mood and under 72 characters, with optional bodies that explain rationale and validation. Pull requests should link related issues, summarize affected commands, list new action scripts or configs, and note any manual steps (for example, regenerating `repos_filtered.json`). Include screenshots or logs when they clarify action output.

## Agent-Specific Tips
Scripts rely on `Mix.install`, so the first run fetches dependencies automatically. If you integrate LLM actions, provide `GEMINI_API_KEY` or `ANTHROPIC_API_KEY` in the environment before invoking `elixir run.exs analyze`. When debugging, use `IO.inspect/2` sparingly and remove temporary output before merging.
