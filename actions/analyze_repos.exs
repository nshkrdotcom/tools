#!/usr/bin/env elixir

# Analyze Elixir repos against a reference repo using Gemini and Claude
#
# This action analyzes target repositories against a reference repository.
# It extracts key metadata from each repo and creates LLM prompts for analysis.
#
# Reference repo: ../gemini_ex (HARDCODED - change @reference_repo to modify)
#
# What it checks:
#   1. Has Logo - Presence of logo files (logo.png, logo.svg, logo.jpg)
#   2. Hex Publishing Format - mix.exs structure for Hex publishing
#   3. Documentation Quality - README completeness
#   4. Project Metadata - Package info structure
#   5. Future checks (stubbed):
#      - CI/CD setup
#      - Testing setup
#      - Code style/formatting
#
# Current status: STUBBED - Ready for LLM integration
# To integrate: Add Mix.install with gemini_ex or claude_code_sdk_elixir
#               Replace stub in analyze_repo/2 with actual LLM call
#
# Usage:
#   elixir run.exs analyze

defmodule Actions.AnalyzeRepos do
  @moduledoc """
  Analyzes Elixir repositories against a reference repository using LLM.
  Currently stubbed - ready for integration with Gemini or Claude.
  """

  # HARDCODED REFERENCE REPO - Change this to use a different reference
  @reference_repo "../gemini_ex"

  @doc """
  Extracts key files and metadata from a repository.
  Returns map with has_logo, mix_exs, and readme content.
  """
  def get_repo_files(repo_path) do
    # Check for logo
    logo_patterns = ~w(logo.png logo.svg logo.jpg)

    has_logo =
      Enum.any?(logo_patterns, fn pattern ->
        File.exists?(Path.join(repo_path, pattern))
      end)

    # Read mix.exs
    mix_exs =
      case File.read(Path.join(repo_path, "mix.exs")) do
        {:ok, content} -> content
        _ -> nil
      end

    # Read README
    readme =
      ["README.md", "README", "readme.md"]
      |> Enum.find_value(fn filename ->
        case File.read(Path.join(repo_path, filename)) do
          {:ok, content} -> content
          _ -> nil
        end
      end)

    %{
      has_logo: has_logo,
      mix_exs: mix_exs,
      readme: readme
    }
  end

  def create_analysis_prompt(ref_files, target_files, target_name) do
    """
    You are analyzing an Elixir project called '#{target_name}' against a reference project.

    REFERENCE PROJECT FILES:
    ======================

    mix.exs:
    ```
    #{String.slice(ref_files.mix_exs || "N/A", 0, 2000)}
    ```

    README.md:
    ```
    #{String.slice(ref_files.readme || "N/A", 0, 2000)}
    ```

    Has Logo: #{ref_files.has_logo}

    TARGET PROJECT FILES:
    ====================

    mix.exs:
    ```
    #{String.slice(target_files.mix_exs || "N/A", 0, 2000)}
    ```

    README.md:
    ```
    #{String.slice(target_files.readme || "N/A", 0, 2000)}
    ```

    Has Logo: #{target_files.has_logo}

    ANALYSIS TASKS:
    ==============

    Please analyze the target project and provide a brief assessment:

    1. **Has Logo**: Does the target have a logo file? (Yes/No)

    2. **Hex Publishing Format**: Does mix.exs follow proper format for Hex publishing?
       - Check for: package description, licenses, links, source_url, homepage_url
       - Compare to reference format

    3. **Documentation Quality**: Brief comparison of README quality

    4. **Project Metadata**: Is package info well-structured?

    5. **Future Checks** (stub for now):
       - CI/CD setup (stub)
       - Testing setup (stub)
       - Code style/formatting (stub)

    Provide a concise summary (3-5 lines) with specific actionable items if any are missing.
    """
  end

  def analyze_repo(ref_files, target_path) do
    target_name = Path.basename(target_path)
    ref_path = Path.expand(@reference_repo)

    # Skip if this is the reference repo
    if Path.expand(target_path) == ref_path do
      IO.puts("⊙ #{target_name} - SKIPPED (reference repo)")
      nil
    else
      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("Analyzing: #{target_name}")
      IO.puts(String.duplicate("=", 60))

      target_files = get_repo_files(target_path)
      prompt = create_analysis_prompt(ref_files, target_files, target_name)

      # STUB: This is where you'd call Gemini or Claude
      # For now, just print that we would analyze
      IO.puts("📝 STUB: Would analyze with LLM")
      IO.puts("   Prompt ready (#{String.length(prompt)} chars)")
      IO.puts("   Has logo: #{target_files.has_logo}")
      IO.puts("   Has mix.exs: #{!is_nil(target_files.mix_exs)}")
      IO.puts("   Has README: #{!is_nil(target_files.readme)}")

      # TODO: Uncomment when ready to use LLMs
      # result = call_gemini(prompt) or call_claude(prompt)
      # IO.puts(result)

      :ok
    end
  end

  def run(repos) do
    IO.puts("\n🔍 Using REFERENCE REPO: #{@reference_repo}")
    IO.puts("   (explicitly hardcoded in script)")

    ref_path = Path.expand(@reference_repo)

    unless File.dir?(ref_path) do
      IO.puts("Error: Reference repo not found at #{ref_path}")
      System.halt(1)
    end

    IO.puts("   Loading reference files from #{Path.basename(ref_path)}...")
    ref_files = get_repo_files(ref_path)
    IO.puts("   ✓ Reference loaded (has_logo: #{ref_files.has_logo})")

    IO.puts("\n📊 Analyzing #{length(repos)} repos...\n")

    Enum.each(repos, fn repo ->
      analyze_repo(ref_files, repo)
    end)

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("ANALYSIS COMPLETE")
    IO.puts(String.duplicate("=", 60))
  end
end
