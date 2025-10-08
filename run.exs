#!/usr/bin/env elixir

# Main runner script for Elixir repo management
#
# This is the main entry point for the repository management tool.
# It provides commands for scanning, filtering, and running actions on Elixir repos.
#
# Commands:
#   elixir run.exs                - Show help
#   elixir run.exs scan           - Scan for Elixir repos
#   elixir run.exs filter         - Filter repos
#   elixir run.exs setup          - Run scan + filter
#   elixir run.exs uncommitted    - Check for uncommitted work
#   elixir run.exs analyze        - Analyze repos (stubbed)
#   elixir run.exs placeholder    - Run placeholder action
#
# Workflow:
#   1. Run 'setup' to scan and filter repositories
#   2. Edit repos_exclude.json to customize exclusions (optional)
#   3. Run 'filter' to regenerate filtered list (if you edited exclusions)
#   4. Run actions like 'uncommitted' or 'analyze'
#
# Adding new actions:
#   1. Create actions/your_action.exs with Actions.YourAction module
#   2. Add command case in run/1 function below
#   3. Add module mapping in run_action/1 function below

Mix.install([{:jason, "~> 1.4"}])

defmodule Runner do
  @moduledoc """
  Main runner module for repository management commands.
  """

  @doc """
  Loads repository list from JSON file.
  Returns empty list and prints error if file not found.
  """
  def load_repos(filename) do
    case File.read(filename) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"repos" => repos}} -> repos
          _ -> []
        end

      {:error, _} ->
        IO.puts("Error: #{filename} not found. Run setup first.")
        []
    end
  end

  def run_action(action_file) do
    repos = load_repos("repos_filtered.json")

    if Enum.empty?(repos) do
      IO.puts("No repos found. Run setup first.")
      System.halt(1)
    end

    # Load and run the action module
    Code.require_file(action_file)

    # Get the module name from the file
    module_name =
      case action_file do
        "actions/check_uncommitted.exs" -> Actions.CheckUncommitted
        "actions/analyze_repos.exs" -> Actions.AnalyzeRepos
        "actions/placeholder.exs" -> Actions.Placeholder
        _ -> nil
      end

    if module_name do
      apply(module_name, :run, [repos])
    else
      IO.puts("Unknown action: #{action_file}")
      System.halt(1)
    end
  end

  def print_usage do
    IO.puts("""
    Elixir Repo Management Tool

    Usage:
      elixir run.exs scan          - Scan for Elixir repos and create configs
      elixir run.exs filter        - Filter repos (main - excludes)
      elixir run.exs setup         - Run scan + filter
      elixir run.exs uncommitted   - Check for uncommitted work
      elixir run.exs analyze       - Analyze repos (stubbed for LLM integration)
      elixir run.exs placeholder   - Run placeholder action
    """)
  end

  def run(args) do
    case args do
      ["scan"] ->
        IO.puts("=== Scanning for Elixir repos ===")
        Code.require_file("scan_repos.exs")

      ["filter"] ->
        IO.puts("=== Filtering repos ===")
        Code.require_file("filter_repos.exs")

      ["setup"] ->
        IO.puts("=== Running setup (scan + filter) ===")
        Code.require_file("scan_repos.exs")
        IO.puts("")
        Code.require_file("filter_repos.exs")

      ["uncommitted"] ->
        IO.puts("=== Checking for uncommitted work ===")
        run_action("actions/check_uncommitted.exs")

      ["analyze"] ->
        IO.puts("=== Analyzing repos ===")
        run_action("actions/analyze_repos.exs")

      ["placeholder"] ->
        IO.puts("=== Running placeholder action ===")
        run_action("actions/placeholder.exs")

      _ ->
        print_usage()
    end
  end
end

Runner.run(System.argv())
