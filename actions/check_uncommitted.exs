#!/usr/bin/env elixir

# Check for uncommitted work in repositories
#
# This action checks each repository for uncommitted changes using git status.
#
# For each repo, it runs: git status --porcelain
# - If output is empty, repo is clean
# - If output has content, repo has uncommitted changes
#
# Output:
#   - Lists each repo with ✓ (clean) or ✗ (has changes)
#   - Summary of repos with uncommitted work
#
# Usage:
#   elixir run.exs uncommitted

defmodule Actions.CheckUncommitted do
  @moduledoc """
  Checks repositories for uncommitted changes.
  """

  @doc """
  Checks if a repository has uncommitted changes.
  Returns true if there are uncommitted changes, false otherwise.
  """
  def check_uncommitted(repo_path) do
    case System.cmd("git", ["status", "--porcelain"], cd: repo_path, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output) != ""
      _ -> false
    end
  end

  def run(repos) do
    repos_with_changes =
      Enum.filter(repos, fn repo ->
        repo_name = Path.basename(repo)
        has_changes = check_uncommitted(repo)

        if has_changes do
          IO.puts("✗ #{repo_name} - has uncommitted changes")
        else
          IO.puts("✓ #{repo_name} - clean")
        end

        has_changes
      end)

    IO.puts("")

    if Enum.empty?(repos_with_changes) do
      IO.puts("All repos are clean!")
    else
      IO.puts("Repos with uncommitted work (#{length(repos_with_changes)}):")

      Enum.each(repos_with_changes, fn repo ->
        IO.puts("  - #{repo}")
      end)
    end
  end
end
