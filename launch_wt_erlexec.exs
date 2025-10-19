#!/usr/bin/env elixir

# Launch a Windows Terminal window from WSL using erlexec for reliable process control.
# Opens three tabs; the third runs a sample command while keeping the shell open.

defmodule LaunchWTErlexec do
  @max_tab_attempts 8
  @retry_delay_ms 150

  def run do
    wt_path = locate!("wt.exe")

    tabs = [
      ~s[echo "Tab 1 ready"; pwd],
      ~s[echo "Tab 2 starting..."; echo "Current directory:"; pwd; echo "Listing files:"; ls -la; echo "System info:"; uname -a; echo "Done!"]
    ]

    IO.puts("Launching Windows Terminal via #{wt_path}...")

    # Create a new window with the first tab, then add remaining tabs
    with {:ok, window_target} <- create_window_with_first_tab(wt_path, hd(tabs)),
         :ok <- open_remaining_tabs(wt_path, window_target, tl(tabs)) do
      IO.puts("All tabs opened successfully.")
    else
      {:error, reason} ->
        IO.puts(:stderr, format_error(reason))
        System.halt(1)
    end
  end

  defp create_window_with_first_tab(wt_path, command) do
    IO.puts("  - Tab 1: #{command_label(command)}")
    args = ["-w", "new", "new-tab"] ++ command_args(command)

    case run_wt_command(wt_path, args) do
      {:ok, streams} ->
        window_target = extract_window_target(streams) || "last"
        IO.puts("    ↪ targeting window #{window_target}")
        {:ok, window_target}

      {:error, reason} ->
        {:error, {:first_tab_failed, reason}}
    end
  end

  defp open_all_tabs(wt_path, window_target, tabs) do
    tabs
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {command, index}, :ok ->
      IO.puts("  - Tab #{index}: #{command_label(command)}")

      case open_tab_with_command(wt_path, window_target, command) do
        {:ok, _streams} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, {:tab_failed, index, reason}}}
      end
    end)
  end

  defp open_tab_with_command(wt_path, window_target, command) do
    args = ["-w", window_target, "new-tab"] ++ command_args(command)
    run_with_retry(fn -> run_wt_command(wt_path, args) end, @max_tab_attempts)
  end

  defp open_remaining_tabs(_wt_path, _target, []), do: :ok

  defp open_remaining_tabs(wt_path, window_target, tabs) do
    tabs
    |> Enum.with_index(2)
    |> Enum.reduce_while(:ok, fn {command, index}, :ok ->
      IO.puts("  - Tab #{index}: #{command_label(command)}")

      case open_additional_tab(wt_path, window_target, command) do
        {:ok, _streams} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, {:tab_failed, index, reason}}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp open_additional_tab(wt_path, window_target, command) do
    args = ["-w", window_target, "new-tab"] ++ command_args(command)
    run_with_retry(fn -> run_wt_command(wt_path, args) end, @max_tab_attempts)
  end

  defp run_with_retry(fun, max_attempts), do: run_with_retry(fun, max_attempts, 1)

  defp run_with_retry(_fun, max_attempts, attempt) when attempt > max_attempts,
    do: {:error, :too_many_attempts}

  defp run_with_retry(fun, max_attempts, attempt) do
    case fun.() do
      {:ok, streams} ->
        {:ok, streams}

      {:error, reason} = error ->
        if attempt < max_attempts and retryable_error?(reason) do
          Process.sleep(@retry_delay_ms * attempt)
          run_with_retry(fun, max_attempts, attempt + 1)
        else
          error
        end
    end
  end

  defp run_wt_command(wt_path, args) do
    if dry_run?() do
      IO.puts("    ↪ DRY-RUN #{format_invocation(wt_path, args)}")
      {:ok, %{stdout: "", stderr: ""}}
    else
      IO.puts("    ↪ #{format_invocation(wt_path, args)}")
      {output, status} = System.cmd(wt_path, args, stderr_to_stdout: true)

      result = %{stdout: output, stderr: ""}

      # Log output if there's anything
      if String.trim(output) != "" do
        IO.puts("      OUTPUT: #{String.trim(output)}")
      end

      if status == 0 do
        {:ok, result}
      else
        IO.puts("      ERROR: Exit status #{status}")
        {:error, {:exec_failure, status, output}}
      end
    end
  end

  defp extract_window_target(%{stdout: stdout, stderr: stderr}) do
    [stdout, stderr]
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.find_value(&first_word_digit/1)
  end

  defp extract_window_target(_), do: nil

  defp first_word_digit(text) do
    case Regex.run(~r/\bwindow\s+(\d+)/i, text) do
      [_, id] ->
        id

      _ ->
        case Regex.run(~r/\b(\d+)\b/, text) do
          [_, id] -> id
          _ -> nil
        end
    end
  end

  defp retryable_error?(reason) do
    output =
      case reason do
        {:exec_failure, _status, text} -> text
        {:error, {:exec_failure, _status, text}} -> text
        _ -> ""
      end

    output != "" and String.contains?(String.downcase(output), "window")
  end

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

  defp command_args(nil), do: blank_tab_args()

  defp command_args_for_new_window(command) do
    script_or_placeholder = prepare_command_command(command)

    [
      wsl_executable(),
      "--exec",
      bash_executable(),
      script_or_placeholder
    ]
  end

  defp command_args(command) do
    script_or_placeholder = prepare_command_command(command)

    [
      "--",
      wsl_executable(),
      "--exec",
      bash_executable(),
      script_or_placeholder
    ]
  end

  defp prepare_command_command(command) do
    command_with_exec = ensure_exec(command)

    cond do
      dry_run?() ->
        "-- dry-run: #{String.replace(command_with_exec, ~r/\s+/, " ")}"

      true ->
        create_temp_script(command_with_exec)
    end
  end

  defp ensure_exec(command) do
    trimmed = String.trim(command)

    if String.ends_with?(trimmed, "; exec bash") do
      trimmed
    else
      trimmed <> "; exec bash"
    end
  end

  defp create_temp_script(command) do
    tmp_dir = System.tmp_dir!() |> Path.expand()
    script_path = Path.join(tmp_dir, "wt_cmd_#{System.unique_integer([:positive])}.sh")

    contents = """
    #!/bin/bash
    set -e
    trap 'rm -f "$0"' EXIT
    #{command}
    """

    File.write!(script_path, contents)
    File.chmod!(script_path, 0o700)
    script_path
  end

  defp wsl_executable, do: System.get_env("WT_WSL_EXE") || "wsl.exe"

  defp bash_executable do
    System.get_env("WT_BASH_EXE") || "/bin/bash"
  end

  defp blank_tab_args do
    case System.get_env("WT_DEFAULT_COMMAND") do
      nil -> []
      command -> ["--", command]
    end
  end

  defp autoguess_wsl_profile do
    settings_candidates()
    |> Enum.reduce_while({:error, :settings_not_found}, fn path, acc ->
      case extract_profile_from_settings(path) do
        {:ok, profile} -> {:halt, {:ok, profile}}
        _ -> {:cont, acc}
      end
    end)
  end

  defp extract_profile_from_settings(path) do
    cond do
      not File.regular?(path) ->
        {:error, :no_file}

      true ->
        with {:ok, profile} <- extract_profile_with_jq(path) do
          {:ok, profile}
        else
          _ ->
            fallback_profile_from_file(path)
        end
    end
  end

  defp extract_profile_with_jq(path) do
    case System.find_executable("jq") do
      nil ->
        {:error, :jq_missing}

      jq ->
        filter =
          "(.profiles.list // .profiles // [])" <>
            " | map(select(((.source? // \"\") | ascii_downcase | test(\"wsl\"))" <>
            " or ((.name? // \"\") | ascii_downcase | test(\"ubuntu\"))" <>
            " or ((.commandline? // \"\") | ascii_downcase | test(\"wsl\"))))" <>
            " | map(.guid // .name)[]"

        case System.cmd(jq, ["-r", filter, path]) do
          {output, 0} ->
            output
            |> String.split("\n", trim: true)
            |> Enum.find(&(&1 != "" and &1 != "null"))
            |> case do
              nil -> {:error, :no_match}
              value -> {:ok, value}
            end

          _ ->
            {:error, :jq_failure}
        end
    end
  end

  defp fallback_profile_from_file(path) do
    case File.read(path) do
      {:ok, contents} ->
        downcased = String.downcase(contents)

        with {:ok, value} <- extract_guid_near_source(contents, downcased),
             true <- value != "" do
          {:ok, value}
        else
          _ ->
            case extract_guid_near_name(contents, downcased) do
              {:ok, value} when value != "" -> {:ok, value}
              _ -> {:error, :no_wsl_profile}
            end
        end

      error ->
        error
    end
  end

  defp extract_guid_near_source(contents, downcased) do
    regex = ~r/"guid"\s*:\s*"([^"]+)"[\s\S]*?"source"\s*:\s*"([^"]*)"/

    contents
    |> Regex.scan(regex)
    |> Enum.zip(Regex.scan(regex, downcased))
    |> Enum.find_value(fn {[_full, guid, _source], [_f2, _guid2, source_down]} ->
      if String.contains?(source_down, "wsl") or String.contains?(source_down, "canonical") do
        {:ok, guid}
      else
        nil
      end
    end)
    |> case do
      nil -> {:error, :no_match}
      result -> result
    end
  end

  defp extract_guid_near_name(contents, downcased) do
    regex = ~r/"guid"\s*:\s*"([^"]+)"[\s\S]*?"name"\s*:\s*"([^"]+)"/

    contents
    |> Regex.scan(regex)
    |> Enum.zip(Regex.scan(regex, downcased))
    |> Enum.find_value(fn {[_full, guid, _name], [_f2, _guid2, name_down]} ->
      if String.contains?(name_down, "ubuntu") or String.contains?(name_down, "wsl") do
        {:ok, guid}
      else
        nil
      end
    end)
    |> case do
      nil -> {:error, :no_match}
      result -> result
    end
  end

  defp settings_candidates do
    env = System.get_env("WT_SETTINGS_PATH")

    explicit =
      case env do
        nil -> []
        _ -> [Path.expand(env)]
      end

    from_localappdata =
      case resolve_localappdata() do
        {:ok, localappdata} ->
          [
            Path.join([
              localappdata,
              "Packages",
              "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
              "LocalState",
              "settings.json"
            ])
          ]

        _ ->
          []
      end

    from_env_user =
      case System.get_env("WT_WINDOWS_USER") || System.get_env("USERNAME") do
        nil ->
          []

        user ->
          [
            Path.join([
              "/mnt/c/Users",
              user,
              "AppData/Local/Packages",
              "Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
            ])
          ]
      end

    from_users_folder =
      case File.ls("/mnt/c/Users") do
        {:ok, entries} ->
          entries
          |> Enum.reject(&String.starts_with?(&1, "."))
          |> Enum.map(fn user ->
            Path.join([
              "/mnt/c/Users",
              user,
              "AppData/Local/Packages",
              "Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
            ])
          end)

        _ ->
          []
      end

    (explicit ++ from_localappdata ++ from_env_user ++ from_users_folder)
    |> Enum.filter(& &1)
    |> Enum.uniq()
  end

  defp command_label(nil), do: "default shell"
  defp command_label(command), do: "command: #{String.trim(command)}"

  defp format_error({:primary_window_failed, reason}) do
    "Failed to open the initial Windows Terminal window. " <> format_reason(reason)
  end

  defp format_error({:tab_failed, index, reason}) do
    "Failed to open tab #{index}. " <> format_reason(reason)
  end

  defp format_error(other), do: "Failed to open Windows Terminal tabs. " <> format_reason(other)

  defp format_reason({:error, reason}), do: format_reason(reason)

  defp format_reason({:exec_failure, status, output}) do
    trimmed = String.trim(output || "")

    [
      "exit status #{status}",
      trimmed != "" && "output: #{trimmed}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  defp format_reason({:too_many_attempts}), do: "Too many attempts."
  defp format_reason(other), do: inspect(other)

  defp dry_run? do
    case System.get_env("WT_DRY_RUN") do
      nil -> false
      value -> String.downcase(value) in ["1", "true", "yes"]
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

  defp resolve_localappdata do
    cond do
      path = System.get_env("WT_LOCALAPPDATA") ->
        {:ok, Path.expand(path)}

      path = System.get_env("LOCALAPPDATA") ->
        {:ok, Path.expand(path)}

      true ->
        with {:ok, win_path} <- windows_env("LOCALAPPDATA"),
             {:ok, wsl_path} <- windows_to_wsl(win_path) do
          {:ok, wsl_path}
        else
          _ -> {:error, :unavailable}
        end
    end
  end

  defp windows_env(var) do
    script_path = Path.expand("scripts/get_windows_env.sh", File.cwd!())

    cond do
      not File.exists?(script_path) ->
        {:error, :script_missing}

      true ->
        case System.cmd(script_path, [var]) do
          {value, 0} ->
            {:ok, String.trim(value)}

          {_value, _} ->
            {:error, :not_found}
        end
    end
  end

  defp windows_to_wsl(path) do
    case System.cmd("wslpath", ["-u", path]) do
      {value, 0} ->
        {:ok, String.trim(value)}

      _ ->
        {:error, :conversion_failed}
    end
  end
end

LaunchWTErlexec.run()
