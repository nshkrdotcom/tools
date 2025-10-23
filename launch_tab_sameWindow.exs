#!/usr/bin/env elixir

# Launch a new tab in the current Windows Terminal window.
# Opens WSL to a specified directory.

defmodule LaunchTabSameWindow do
  def run do
    wt_path = locate!("wt.exe")

    # Get the directory from command line args, default to ~/p/g/n
    dir = parse_directory(System.argv())

    IO.puts("Opening new tab in current window...")
    IO.puts("Directory: #{dir}")

    # Build the command to open a new tab
    args = [
      # Target the last active window
      "-w",
      "last",
      "new-tab",
      "--startingDirectory",
      dir
    ]

    IO.puts("Command: #{format_invocation(wt_path, args)}")

    {output, status} = System.cmd(wt_path, args, stderr_to_stdout: true)

    if status == 0 do
      IO.puts("✓ Tab opened successfully")
    else
      IO.puts(:stderr, "✗ Failed to open tab (exit status #{status})")

      if String.trim(output) != "" do
        IO.puts(:stderr, "Output: #{String.trim(output)}")
      end

      System.halt(1)
    end
  end

  defp parse_directory([]), do: "~/p/g/n"
  defp parse_directory([dir | _]), do: dir

  defp locate!(executable) do
    case System.find_executable(executable) do
      nil ->
        IO.puts(
          :stderr,
          "#{executable} not found on PATH. Install Windows Terminal or expose #{executable} to WSL."
        )

        System.halt(1)

      path ->
        path
    end
  end

  defp format_invocation(cmd, args) do
    [cmd | args]
    |> Enum.map(&quote_for_display/1)
    |> Enum.join(" ")
  end

  defp quote_for_display(arg) when is_binary(arg) do
    if Regex.match?(~r/[\s"]/u, arg) do
      escaped = String.replace(arg, "\"", "\\\"")
      ~s("#{escaped}")
    else
      arg
    end
  end
end

LaunchTabSameWindow.run()
