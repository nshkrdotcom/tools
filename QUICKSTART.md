# Quick Start Guide

## First Time Setup

```bash
# 1. Scan and filter repos
elixir run.exs setup

# This creates:
# - repos.json (all found repos)
# - repos_exclude.json (all except DSPex)
# - repos_filtered.json (final list = repos - excludes)
```

## Common Workflows

### Check for Uncommitted Work

```bash
elixir run.exs uncommitted
```

### Analyze Repos (Stubbed)

```bash
elixir run.exs analyze
```

### Custom Exclusions

```bash
# 1. Run initial scan
elixir run.exs scan

# 2. Edit repos_exclude.json
# Remove repos you want to INCLUDE in the filtered list
# (repos_exclude.json contains repos to EXCLUDE)

# 3. Regenerate filtered list
elixir run.exs filter

# 4. Run actions on filtered repos
elixir run.exs uncommitted
```

## Files Generated

- `repos.json` - All Elixir git repos found in parent directory
- `repos_exclude.json` - Repos to exclude (edit this to customize)
- `repos_filtered.json` - Final list used by actions (repos - excludes)

## Key Points

- **Parent directory**: Scripts scan `..` (parent of tools directory)
- **Criteria**: Must be both git repo (has `.git/`) AND Elixir project (has `mix.exs`)
- **Default exclude**: DSPex is excluded by default
- **Reference repo**: `../gemini_ex` (hardcoded in analyze action)

## Creating Custom Actions

```bash
# 1. Copy template
cp actions/placeholder.exs actions/my_action.exs

# 2. Edit actions/my_action.exs
# - Change module name to Actions.MyAction
# - Implement run/1 function

# 3. Add to run.exs
# Add case for ["my-action"] -> run_action("actions/my_action.exs")
# Add case for "actions/my_action.exs" -> Actions.MyAction

# 4. Test it
elixir run.exs my-action
```

## Troubleshooting

```bash
# No repos found?
cd /home/home/p/g/n/tools
ls ..  # Make sure parent has Elixir repos

# Dependencies not installing?
elixir --version  # Check Elixir installed
rm -rf ~/.hex ~/.mix  # Clear cache if needed

# Reference repo not found?
# Edit actions/analyze_repos.exs
# Change @reference_repo to point to existing repo
```

## Next Steps

1. ✅ Run `elixir run.exs setup`
2. ✅ Test with `elixir run.exs uncommitted`
3. 📝 Customize `repos_exclude.json` if needed
4. 🔨 Integrate LLMs in `actions/analyze_repos.exs`
5. ➕ Create custom actions for your needs
