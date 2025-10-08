#!/usr/bin/env elixir

# Filter repos by subtracting excludes from main list
#
# This script filters repositories by subtracting the exclude list from the main list.
# Formula: repos_filtered = repos - repos_exclude
#
# Input files:
#   - repos.json: Main list of all repositories
#   - repos_exclude.json: Repositories to exclude
#
# Output:
#   - repos_filtered.json: Final filtered list (main - excludes)
#
# Usage:
#   elixir filter_repos.exs
#   or
#   elixir run.exs filter

Mix.install([{:jason, "~> 1.4"}])

defmodule RepoFilter do
  @moduledoc """
  Filters repository list by subtracting excluded repos from main list.
  """

  @doc """
  Loads repository list from JSON file.
  Returns empty list if file not found.
  """
  def load_repos(filename) do
    case File.read(filename) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"repos" => repos}} -> repos
          _ -> []
        end

      {:error, _} ->
        IO.puts("Error: #{filename} not found. Run scan_repos.exs first.")
        []
    end
  end

  def filter_repos do
    main_repos = load_repos("repos.json")
    exclude_repos = load_repos("repos_exclude.json")

    # Subtract: repos in main but NOT in exclude
    main_repos -- exclude_repos
  end

  def run do
    filtered = filter_repos()

    # Save filtered list
    filtered_json = Jason.encode!(%{repos: filtered}, pretty: true)
    File.write!("repos_filtered.json", filtered_json)

    IO.puts("Filtered repos: #{length(filtered)}")

    Enum.each(filtered, fn repo ->
      IO.puts("  - #{repo}")
    end)
  end
end

RepoFilter.run()
