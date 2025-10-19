#!/usr/bin/env elixir

# Launch a Windows Terminal window from WSL using erlexec for reliable process control.
# Opens three tabs; the third runs a sample command while keeping the shell open.

Mix.install([
  {:erlexec, "~> 2.0"}
])

unless System.find_executable("wt.exe") do
  IO.puts("wt.exe not found on PATH. Install Windows Terminal or expose wt.exe to WSL.")
  System.halt(1)
end

tabs = [
  nil,
  nil,
  ~s[echo "Tab 3 launched via erlexec"; date]
]

ensure_exec = fn command ->
  trimmed = String.trim(command)

  if String.ends_with?(trimmed, "; exec bash") do
    trimmed
  else
    trimmed <> "; exec bash"
  end
end

{:ok, _} =
  case :exec.start_link([]) do
    {:ok, pid} -> {:ok, pid}
    {:error, {:already_started, pid}} -> {:ok, pid}
  end

tabs
|> Enum.with_index()
|> Enum.each(fn {maybe_command, index} ->
  args =
    case {index, maybe_command} do
      {0, nil} -> ["new-tab", "wsl"]
      {0, command} -> ["new-tab", "wsl", "--", "bash", "-lc", ensure_exec.(command)]
      {_, nil} -> ["-w", "0", "new-tab", "wsl"]
      {_, command} -> ["-w", "0", "new-tab", "wsl", "--", "bash", "-lc", ensure_exec.(command)]
    end

  case :exec.run(["wt.exe" | args], [:sync, :stdout, :stderr]) do
    {:ok, _} ->
      IO.puts("Opened tab #{index + 1} (command: #{maybe_command || "default shell"})")

    {:error, details} ->
      IO.puts("Failed to open tab #{index + 1}. Details: #{inspect(details)}")
  end
end)
