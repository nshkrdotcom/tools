#!/usr/bin/env elixir

# Minimal proof-of-concept: launch a few Windows Terminal tabs (via wt.exe)
# from an Elixir script. Each tab drops into WSL, runs a command, then leaves
# an interactive bash session open.

tab_count = 3

# Populate with `nil` to open blank WSL shells. Replace entries with strings later if desired.
commands = List.duplicate(nil, tab_count)

unless System.find_executable("wt.exe") do
  IO.puts("""
  Could not find wt.exe on PATH.
  Make sure Windows Terminal is installed and wt.exe is reachable from WSL.
  """)

  System.halt(1)
end

IO.puts("Launching Windows Terminal tabs via wt.exe...")

commands
|> Enum.with_index()
|> Enum.each(fn {maybe_command, index} ->
  args =
    case {index, maybe_command} do
      {0, nil} ->
        # Use new-window so we don't get an extra default tab when wt.exe boots up.
        ["new-window", "wsl"]

      {0, command} ->
        ["new-window", "wsl", "--", "bash", "-lc", "#{String.trim(command)}; exec bash"]

      {_, nil} ->
        ["-w", "0", "new-tab", "wsl"]

      {_, command} ->
        ["-w", "0", "new-tab", "wsl", "--", "bash", "-lc", "#{String.trim(command)}; exec bash"]
    end

  IO.inspect(args, label: "Launching tab #{index + 1}")
  System.cmd("wt.exe", args)
end)
