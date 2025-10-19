# Elixir Repo Management Tool

A streamlined system for managing and running batch operations across multiple Elixir repositories.

## Overview

This tool provides a simple framework for:
- Scanning a directory for Elixir git repositories
- Filtering repositories based on exclude lists
- Running custom actions across filtered repositories
- Extensible action system for batch operations

## Installation

### Prerequisites

- Elixir 1.14 or higher
- Git
- (Optional) API keys for LLM integrations (Gemini, Claude)

### Setup

1. The scripts use `Mix.install` and will automatically download dependencies on first run
2. For LLM features (when you implement them), set environment variables:

```bash
export GEMINI_API_KEY="your-gemini-key"
export ANTHROPIC_API_KEY="your-claude-key"
```

## Quick Start

```bash
# 1. Initial setup - scan parent directory and create filtered list
elixir run.exs setup

# 2. Run actions on filtered repos
elixir run.exs uncommitted    # Check for uncommitted work
elixir run.exs analyze        # Analyze repos (stubbed for LLM)
elixir run.exs placeholder    # Run your custom action
```

## How It Works

### 1. Scan Phase (`scan_repos.exs`)

Scans the parent directory (`..`) for repositories that are:
- Git repositories (contain `.git` directory)
- Elixir projects (contain `mix.exs` file)

**Outputs:**
- `repos.json` - All found repositories
- `repos_exclude.json` - All repositories EXCEPT DSPex (modify as needed)

**Example:**
```bash
elixir run.exs scan
# or directly:
elixir scan_repos.exs
```

### 2. Filter Phase (`filter_repos.exs`)

Creates a final filtered list by subtracting excluded repos from the main list:
- Reads `repos.json` (main list)
- Reads `repos_exclude.json` (exclusion list)
- Creates `repos_filtered.json` (main - excludes)

**Example:**
```bash
elixir run.exs filter
# or directly:
elixir filter_repos.exs
```

### 3. Action Phase

Runs actions on repositories in `repos_filtered.json`.

## Available Commands

### Core Commands

| Command | Description | Output Files |
|---------|-------------|--------------|
| `elixir run.exs` | Show help | - |
| `elixir run.exs scan` | Scan for Elixir repos | `repos.json`, `repos_exclude.json` |
| `elixir run.exs filter` | Filter repos | `repos_filtered.json` |
| `elixir run.exs setup` | Run scan + filter | All JSON files |
| `elixir launch_wt_erlexec.exs [N]` | Launch Windows Terminal layouts sized for 4K | `~/.config/wt_launcher/windows.exs` |
| `elixir launch_wt_erlexec.exs --config [path]` | Launch Windows Terminal from a layout file | `~/.config/wt_launcher/windows.exs` |

### Action Commands

| Command | Description | Status |
|---------|-------------|--------|
| `elixir run.exs uncommitted` | Check for uncommitted changes | ✅ Working |
| `elixir run.exs analyze` | Analyze repos with LLM | 🔨 Stubbed |
| `elixir run.exs placeholder` | Template for custom actions | 🔨 Stubbed |

## Action Modules

Actions are located in the `actions/` directory. Each action is a self-contained Elixir script.

### check_uncommitted.exs

Checks each repository for uncommitted changes using `git status --porcelain`.

**Output:**
```
=== Checking for uncommitted work ===
✓ repo1 - clean
✗ repo2 - has uncommitted changes
✓ repo3 - clean

Repos with uncommitted work (1):
  - /path/to/repo2
```

### analyze_repos.exs

Analyzes repositories against a reference repository.

**Features:**
- Hardcoded reference repo: `../gemini_ex`
- Extracts repo metadata (logo, mix.exs, README)
- Creates LLM analysis prompts
- **Currently stubbed** - Ready for LLM integration

**What it checks:**
1. Has Logo - Presence of logo files
2. Hex Publishing Format - mix.exs structure for publishing
3. Documentation Quality - README completeness
4. Project Metadata - Package info structure
5. Future checks (stubbed):
   - CI/CD setup
   - Testing setup
   - Code style/formatting

**Output:**
```
🔍 Using REFERENCE REPO: ../gemini_ex
   (explicitly hardcoded in script)
   ✓ Reference loaded (has_logo: false)

📊 Analyzing 1 repos...

============================================================
Analyzing: DSPex
============================================================
📝 STUB: Would analyze with LLM
   Prompt ready (8981 chars)
   Has logo: false
   Has mix.exs: true
   Has README: true
```

### placeholder.exs

Template for creating custom actions.

**Output:**
```
=== Running placeholder action ===
  Processing: repo1
  Processing: repo2
✓ Placeholder action complete
```

## Windows Terminal Layout Launcher

`launch_wt_erlexec.exs` automates Windows Terminal from WSL with two complementary workflows:

- **Builtin tiling** – `elixir launch_wt_erlexec.exs` (or `… exs N`) tiles the full 3840×2160 desktop for `N = 2..24` windows. Widths are scaled so panes stay usable; heights stretch to fill the display. Each pane gets a named window and a placeholder tab ready for reuse.
- **Config-driven** – `elixir launch_wt_erlexec.exs --config` reads a layout file (example: `config/wt_layout.exs`) that specifies per-window tabs, titles, profiles, positions, and modes. Override the file path with `WT_LAYOUT_CONFIG` or pass it inline.

Every launch persists state to `~/.config/wt_launcher/windows.exs`, capturing UUIDs, window targets, pixel rectangles, and tab metadata. Use those targets later with `wt.exe -w <target>` to add, focus, or close tabs programmatically.

To customize the default layout without editing tracked files, copy `config/wt_layout.local.example.exs` to `config/wt_layout.local.exs` (ignored by git) and set `left_path` / `right_path` to your preferred workspaces. Legacy keys such as `:nordic_road_path` and `:snakepit_path` are still recognized for compatibility.

### Helpful Environment Switches

- `WT_DRY_RUN=1` — Print the commands without opening Windows Terminal (great for validating layouts).
- `WT_WSL_EXE`, `WT_BASH_EXE`, `WT_DEFAULT_COMMAND` — Override the executables/commands used inside tabs.
- `WT_LAYOUT_CONFIG=/path/to/layout.exs` — Force a specific config file without supplying `--config`.

## Creating Custom Actions

1. Create a new file in `actions/` directory (e.g., `actions/my_action.exs`)
2. Define a module with a `run/1` function:

```elixir
#!/usr/bin/env elixir

defmodule Actions.MyAction do
  def run(repos) do
    Enum.each(repos, fn repo ->
      repo_name = Path.basename(repo)
      IO.puts("Processing: #{repo_name}")

      # Your custom logic here
      # - Read files from repo
      # - Run git commands
      # - Analyze code
      # - Generate reports
      # etc.
    end)
  end
end
```

3. Add command to `run.exs`:

```elixir
["my-action"] ->
  IO.puts("=== Running my action ===")
  run_action("actions/my_action.exs")
```

## File Structure

```
tools/
├── run.exs                      # Main runner
├── scan_repos.exs              # Repo scanner
├── filter_repos.exs            # Repo filter
├── mix.exs                     # Project dependencies
├── README.md                   # This file
├── .formatter.exs              # Code formatter config
├── .gitignore                  # Git ignore rules
├── actions/                    # Action modules
│   ├── check_uncommitted.exs   # Check git status
│   ├── analyze_repos.exs       # LLM analysis (stubbed)
│   └── placeholder.exs         # Template action
└── (generated files)
    ├── repos.json              # All found repos
    ├── repos_exclude.json      # Repos minus excludes
    └── repos_filtered.json     # Final filtered list
```

## Configuration

### Modifying Exclusions

Edit `repos_exclude.json` after running scan:

```json
{
  "repos": [
    "/path/to/repo1",
    "/path/to/repo2"
  ]
}
```

Then run `elixir run.exs filter` to regenerate `repos_filtered.json`.

### Changing Reference Repo

Edit `actions/analyze_repos.exs`:

```elixir
# Change this line:
@reference_repo "../gemini_ex"

# To your preferred reference repo:
@reference_repo "../my_reference_repo"
```

## Integrating LLMs

The `analyze_repos.exs` action is stubbed and ready for LLM integration.

### Using Gemini

Dependencies are already in `mix.exs`. To integrate:

```elixir
# In analyze_repos.exs, add after Mix.install if using as script:
Mix.install([
  {:jason, "~> 1.4"},
  {:gemini_ex, "~> 0.1.0"}
])

# Then in analyze_repo function, replace stub with:
def analyze_repo(ref_files, target_path) do
  # ... existing code ...

  prompt = create_analysis_prompt(ref_files, target_files, target_name)

  # Call Gemini
  api_key = System.get_env("GEMINI_API_KEY")
  result = GeminiEx.generate_content(api_key, prompt)
  IO.puts(result)
end
```

### Using Claude

```elixir
# Add to Mix.install:
Mix.install([
  {:jason, "~> 1.4"},
  {:claude_code_sdk_elixir, "~> 0.1.0"}
])

# Replace stub with Claude call:
def analyze_repo(ref_files, target_path) do
  # ... existing code ...

  prompt = create_analysis_prompt(ref_files, target_files, target_name)

  # Call Claude
  api_key = System.get_env("ANTHROPIC_API_KEY")
  result = ClaudeCodeSdk.generate(api_key, prompt)
  IO.puts(result)
end
```

## Troubleshooting

### "No repos found"

- Make sure you ran `elixir run.exs setup` first
- Check that parent directory (`..`) contains Elixir repos
- Verify repos have both `.git/` and `mix.exs`

### "Reference repo not found"

- Check that `../gemini_ex` exists
- Or change `@reference_repo` in `actions/analyze_repos.exs`

### Dependencies not installing

- Ensure internet connection (Mix.install downloads from Hex)
- Check Elixir version: `elixir --version`
- Clear Mix cache: `rm -rf ~/.hex ~/.mix`

## Examples

### Workflow 1: Check All Repos for Uncommitted Work

```bash
# Setup
elixir run.exs setup

# Check status
elixir run.exs uncommitted
```

### Workflow 2: Analyze Repos Against Reference

```bash
# Setup
elixir run.exs setup

# Analyze (currently shows what would be analyzed)
elixir run.exs analyze
```

### Workflow 3: Custom Filtering

```bash
# Initial scan
elixir run.exs scan

# Edit repos_exclude.json to exclude more repos
# Add the full paths of repos you want to exclude

# Re-filter
elixir run.exs filter

# Run action on filtered list
elixir run.exs uncommitted
```

## Design Philosophy

- **Simple**: Plain Elixir scripts using Mix.install
- **Modular**: Actions are independent modules
- **Extensible**: Easy to add new actions
- **Explicit**: Reference repo hardcoded and printed
- **Debuggable**: Console logging throughout
- **Stubbed**: Framework ready for LLM integration

## Future Enhancements

Potential additions (currently stubbed):

- [ ] CI/CD configuration analysis
- [ ] Test coverage reports
- [ ] Code formatting checks
- [ ] Dependency update scanning
- [ ] License compliance checking
- [ ] Documentation completeness scoring
- [ ] Performance benchmarking
- [ ] Security vulnerability scanning

## Contributing

To add a new action:

1. Copy `actions/placeholder.exs` to `actions/your_action.exs`
2. Implement your logic in the `run/1` function
3. Add command mapping in `run.exs`
4. Update this README with your action's documentation

## License

This tool is part of your personal toolkit for managing Elixir repositories.

## Support

For issues or questions:
- Check the troubleshooting section
- Review the code - it's intentionally simple
- Modify as needed for your workflow
