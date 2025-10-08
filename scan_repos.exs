#!/usr/bin/env elixir

# Scan parent directory for Elixir git repositories
#
# This script scans the parent directory (..) for all directories that are both:
# 1. Git repositories (contain .git directory)
# 2. Elixir projects (contain mix.exs file)
#
# Outputs:
#   - repos.json: All found repositories
#   - repos_exclude.json: All repositories EXCEPT DSPex
#
# Usage:
#   elixir scan_repos.exs
#   or
#   elixir run.exs scan

Mix.install([{:jason, "~> 1.4"}])

defmodule RepoScanner do
  @moduledoc """
  Scans parent directory for Elixir git repositories.
  """

  @doc """
  Checks if a path is a git repository by looking for .git directory.
  """
  def git_repo?(path) do
    File.dir?(Path.join(path, ".git"))
  end

  @doc """
  Checks if a path is an Elixir project by looking for mix.exs file.
  """
  def elixir_repo?(path) do
    File.exists?(Path.join(path, "mix.exs"))
  end

  @doc """
  Scans parent directory and returns list of Elixir git repos (sorted).
  """
  def scan_repos(parent_dir) do
    parent_dir
    |> File.ls!()
    |> Enum.map(&Path.join(parent_dir, &1))
    |> Enum.filter(&File.dir?/1)
    |> Enum.filter(fn path ->
      git_repo?(path) and elixir_repo?(path)
    end)
    |> Enum.sort()
  end

  def run do
    parent_dir = Path.expand("..")
    repos = scan_repos(parent_dir)

    # Write full config
    repos_json = Jason.encode!(%{repos: repos}, pretty: true)
    File.write!("repos.json", repos_json)

    IO.puts("Found #{length(repos)} Elixir git repositories")
    IO.puts("Written to repos.json")

    # Create exclude config (removing DSPex)
    excluded_repos = Enum.reject(repos, &String.ends_with?(&1, "DSPex"))
    excluded_json = Jason.encode!(%{repos: excluded_repos}, pretty: true)
    File.write!("repos_exclude.json", excluded_json)

    IO.puts("Created repos_exclude.json with DSPex removed (#{length(excluded_repos)} repos)")
  end
end

RepoScanner.run()
