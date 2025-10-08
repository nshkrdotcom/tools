# Elixir Repo Management Tool

Simple system for managing and running scripts across Elixir repositories.

## Quick Start

```bash
# 1. Initial setup - scan and filter repos
python run.py setup

# 2. Run actions on filtered repos
python run.py uncommitted
```

## How It Works

1. **Scan** (`1_scan_repos.py`): Finds all Elixir git repos in parent directory
   - Creates `repos.json` with all found repos
   - Creates `repos_exclude.json` with DSPex removed

2. **Filter** (`2_filter_repos.py`): Subtracts excludes from main list
   - Creates `repos_filtered.json` with final list

3. **Actions**: Run scripts on filtered repos
   - `action_check_uncommitted.py`: Lists repos with uncommitted work
   - `action_placeholder.py`: Template for custom actions

## Commands

```bash
python run.py scan          # Scan for Elixir repos
python run.py filter        # Filter repos
python run.py setup         # Scan + filter
python run.py uncommitted   # Check uncommitted work
python run.py placeholder   # Run placeholder action
```

## Customization

- Edit `repos_exclude.json` to exclude specific repos
- Create new action scripts using `action_placeholder.py` as template
- Add new commands to `run.py`
