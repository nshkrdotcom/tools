#!/usr/bin/env elixir

# Launch a Windows Terminal window from WSL using erlexec for reliable process control.
# Opens three tabs; the third runs a sample command while keeping the shell open.

defmodule LaunchWTErlexec do
  @max_tab_attempts 8
  @retry_delay_ms 150
  @screen_width_px 3840
  @screen_height_px 2160
  @full_cols 220
  @full_rows 180
  @pixels_per_col @screen_width_px / @full_cols
  @pixels_per_row @screen_height_px / @full_rows
  @min_cols 30
  @min_rows 20
  @default_window_count 2
  @max_windows 24

  def run do
    wt_path = locate!("wt.exe")

    case parse_launch_mode(System.argv()) do
      {:builtin, count} ->
        windows = build_builtin_layout(count)
        launch_layout(wt_path, windows, %{mode: :builtin, window_count: count})

      {:config, path} ->
        case parse_layout_config(path) do
          {:ok, windows} ->
            launch_layout(wt_path, windows, %{mode: :config, config_path: path})

          :no_layout ->
            IO.puts(:stderr, "Layout config #{path} yielded no windows; falling back to builtin.")
            fallback_to_builtin(wt_path)

          {:error, reason} ->
            IO.puts(:stderr, "Failed to load layout config #{path}: #{inspect(reason)}")
            fallback_to_builtin(wt_path)
        end

      {:error, reason} ->
        IO.puts(:stderr, "Invalid arguments: #{format_reason(reason)}")
        fallback_to_builtin(wt_path)
    end
  end

  defp parse_launch_mode(raw_args) do
    raw_args
    |> Enum.reject(&env_assignment?/1)
    |> parse_launch_tokens()
  end

  defp env_assignment?(arg) when is_binary(arg) do
    String.contains?(arg, "=")
  end

  defp env_assignment?(_), do: false

  defp parse_launch_tokens([]), do: {:builtin, @default_window_count}

  defp parse_launch_tokens(["--config"]), do: parse_launch_tokens(["--config", nil])
  defp parse_launch_tokens(["-c"]), do: parse_launch_tokens(["-c", nil])

  defp parse_launch_tokens(["--config", nil]) do
    case default_config_path() do
      {:ok, path} -> {:config, path}
      :error -> {:error, :config_not_found}
    end
  end

  defp parse_launch_tokens(["-c", nil]), do: parse_launch_tokens(["--config", nil])

  defp parse_launch_tokens(["--config", path]) when is_binary(path) do
    {:config, Path.expand(path)}
  end

  defp parse_launch_tokens(["-c", path]) when is_binary(path),
    do: parse_launch_tokens(["--config", path])

  defp parse_launch_tokens([count_str]), do: parse_count_argument(count_str, [])
  defp parse_launch_tokens([count_str | rest]), do: parse_count_argument(count_str, rest)

  defp parse_count_argument(count_str, rest) do
    case Integer.parse(count_str) do
      {count, ""} when count >= 2 and count <= @max_windows ->
        if rest == [] do
          {:builtin, count}
        else
          {:error, :unexpected_additional_arguments}
        end

      {count, ""} ->
        {:error, {:unsupported_count, count}}

      _ ->
        {:error, {:invalid_count, count_str}}
    end
  end

  defp launch_layout(wt_path, windows, metadata) do
    IO.puts("Launching Windows Terminal via #{wt_path}...")

    windows
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {window, index}, {:ok, acc} ->
      case launch_window(wt_path, window, index) do
        {:ok, info} -> {:cont, {:ok, [info | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, infos} ->
        infos = Enum.reverse(infos)
        persist_window_state(infos, metadata)
        IO.puts("All windows opened successfully.")
        :ok

      {:error, reason} ->
        IO.puts(:stderr, format_error(reason))
        System.halt(1)
    end
  end

  defp launch_window(wt_path, window, index) do
    tabs = window_tabs(window)
    [first_tab | remaining_tabs] = tabs

    window_target = window_target(window)
    window_name = window_label(window, window_target)
    uuid = window_uuid(window)
    launch_args = window_launch_switches(window)

    IO.puts("Window #{index}: #{window_name} (target #{window_target})")

    case create_window_with_first_tab(wt_path, window_target, first_tab, launch_args) do
      {:ok, resolved_target} ->
        target_for_tabs = resolved_target || window_target

        case open_remaining_tabs(wt_path, target_for_tabs, remaining_tabs) do
          :ok ->
            {:ok,
             %{
               uuid: uuid,
               target: window_target,
               resolved_target: target_for_tabs,
               label: window_name,
               pixel_rect: window_pixel_rect(window),
               position: window_position(window),
               size: window_size(window),
               tabs: tab_summaries(tabs)
             }}

          {:error, reason} ->
            {:error, {:window_failed, index, reason}}
        end

      {:error, reason} ->
        {:error, {:window_failed, index, reason}}
    end
  end

  defp fallback_to_builtin(wt_path) do
    IO.puts("Falling back to builtin layout with #{@default_window_count} windows.")

    windows = build_builtin_layout(@default_window_count)

    launch_layout(wt_path, windows, %{
      mode: :builtin,
      window_count: @default_window_count,
      fallback: true
    })
  end

  defp build_builtin_layout(count) do
    count
    |> generate_rectangles()
    |> Enum.with_index(1)
    |> Enum.map(fn {rect, index} ->
      label = "Window #{index}"
      target = "auto-#{count}-w#{index}"

      %{
        name: target,
        target: target,
        uuid: builtin_uuid(count, index),
        label: label,
        position: %{x: rect.x, y: rect.y},
        pixel_rect: rect,
        size: %{cols: rect.cols, rows: rect.rows},
        tabs: [
          %{
            label: label,
            title: label,
            command: nil
          }
        ]
      }
    end)
  end

  defp builtin_uuid(count, index) do
    raw = :crypto.hash(:sha256, "#{count}:#{index}") |> Base.encode16(case: :lower)
    "auto-#{String.slice(raw, 0, 12)}"
  end

  defp generate_rectangles(count) when count == 2 do
    grid_layout([2])
  end

  defp generate_rectangles(count) when count == 3 do
    grid_layout([3])
  end

  defp generate_rectangles(count) when count == 4 do
    grid_layout([2, 2])
  end

  defp generate_rectangles(count) when count == 5 do
    layout_five()
  end

  defp generate_rectangles(count) when count == 6 do
    grid_layout([3, 3])
  end

  defp generate_rectangles(count) when count == 7 do
    layout_seven()
  end

  defp generate_rectangles(count) when count == 8 do
    grid_layout([4, 4])
  end

  defp generate_rectangles(count) when count == 9 do
    grid_layout([3, 3, 3])
  end

  defp generate_rectangles(count) when count == 10 do
    grid_layout([5, 5])
  end

  defp generate_rectangles(count) when count >= 11 and count <= @max_windows do
    adaptive_layout(count)
  end

  defp layout_five do
    column_units = [3, 4, 3]
    column_widths = split_by_units(@screen_width_px, column_units)
    half_heights = split_dimension(@screen_height_px, 2)

    left_width = Enum.at(column_widths, 0)
    center_width = Enum.at(column_widths, 1)
    right_width = Enum.at(column_widths, 2)

    top_height = Enum.at(half_heights, 0)
    bottom_height = Enum.at(half_heights, 1)

    [
      %{x: 0, y: 0, width: left_width, height: top_height},
      %{x: 0, y: top_height, width: left_width, height: bottom_height},
      %{x: left_width, y: 0, width: center_width, height: @screen_height_px},
      %{x: left_width + center_width, y: 0, width: right_width, height: top_height},
      %{x: left_width + center_width, y: top_height, width: right_width, height: bottom_height}
    ]
    |> Enum.map(&decorate_rect/1)
  end

  defp layout_seven do
    column_widths = split_dimension(@screen_width_px, 4)
    row_heights = split_dimension(@screen_height_px, 2)

    [w1, w2, w3, w4] = column_widths
    [h1, h2] = row_heights

    [
      %{x: 0, y: 0, width: w1 + w2, height: h1},
      %{x: w1 + w2, y: 0, width: w3, height: h1},
      %{x: w1 + w2 + w3, y: 0, width: w4, height: h1},
      %{x: 0, y: h1, width: w1, height: h2},
      %{x: w1, y: h1, width: w2, height: h2},
      %{x: w1 + w2, y: h1, width: w3, height: h2},
      %{x: w1 + w2 + w3, y: h1, width: w4, height: h2}
    ]
    |> Enum.map(&decorate_rect/1)
  end

  defp adaptive_layout(count) do
    cols = adaptive_columns(count)
    rows = ceil_div(count, cols)
    row_heights = split_dimension(@screen_height_px, rows)

    Stream.unfold({0, 0, count}, fn
      {_, _row_index, remaining} when remaining <= 0 ->
        nil

      {y_offset, row_index, remaining} ->
        row_height = Enum.at(row_heights, row_index)
        cols_in_row = min(cols, remaining)
        widths = split_dimension(@screen_width_px, cols_in_row)

        {row_rects, _} =
          Enum.reduce(widths, {[], 0}, fn width, {acc, x_offset} ->
            rect = %{x: x_offset, y: y_offset, width: width, height: row_height}
            {[decorate_rect(rect) | acc], x_offset + width}
          end)

        {Enum.reverse(row_rects), {y_offset + row_height, row_index + 1, remaining - cols_in_row}}
    end)
    |> Enum.to_list()
    |> List.flatten()
    |> Enum.take(count)
  end

  defp adaptive_columns(count) do
    ratio = @screen_width_px / @screen_height_px
    cols = :math.sqrt(count * ratio) |> :math.ceil() |> trunc()
    min(max(cols, 2), count)
  end

  defp grid_layout(row_columns) do
    total_rows = length(row_columns)
    row_heights = split_dimension(@screen_height_px, total_rows)

    {rects, _} =
      Enum.reduce(Enum.with_index(row_columns), {[], 0}, fn {cols_in_row, row_idx},
                                                            {acc, y_offset} ->
        row_height = Enum.at(row_heights, row_idx)
        widths = split_dimension(@screen_width_px, cols_in_row)

        {row_rects, _} =
          Enum.reduce(widths, {[], 0}, fn width, {row_acc, x_offset} ->
            rect = %{x: x_offset, y: y_offset, width: width, height: row_height}
            {[decorate_rect(rect) | row_acc], x_offset + width}
          end)

        {acc ++ Enum.reverse(row_rects), y_offset + row_height}
      end)

    rects
  end

  defp decorate_rect(rect) do
    cols = columns_from_width(rect.width)
    rows = rows_from_height(rect.height)
    Map.merge(rect, %{cols: cols, rows: rows})
  end

  defp columns_from_width(width_px) do
    width_px
    |> Kernel./(@pixels_per_col)
    |> round()
    |> max(@min_cols)
  end

  defp rows_from_height(height_px) do
    height_px
    |> Kernel./(@pixels_per_row)
    |> round()
    |> max(@min_rows)
  end

  defp split_dimension(size, parts) when parts > 0 do
    base = div(size, parts)
    remainder = rem(size, parts)

    Enum.map(0..(parts - 1), fn index ->
      if index < remainder do
        base + 1
      else
        base
      end
    end)
  end

  defp split_dimension(_size, _parts), do: []

  defp split_by_units(size, units_list) do
    total_units = Enum.sum(units_list)

    units_list
    |> Enum.map(fn units -> units * size / total_units end)
    |> distribute_remainder(size)
  end

  defp distribute_remainder(raw_sizes, target_sum) do
    floors = Enum.map(raw_sizes, &Float.floor/1)
    floor_sum = Enum.sum(floors)
    difference = round(target_sum - floor_sum)

    indexed =
      raw_sizes
      |> Enum.zip(floors)
      |> Enum.with_index()

    adjust_indexes =
      cond do
        difference > 0 ->
          indexed
          |> Enum.sort_by(fn {{raw, floor}, _index} -> raw - floor end, :desc)
          |> Enum.take(difference)
          |> Enum.map(fn {_pair, index} -> index end)
          |> MapSet.new()

        difference < 0 ->
          indexed
          |> Enum.sort_by(fn {{raw, floor}, _index} -> raw - floor end, :asc)
          |> Enum.take(-difference)
          |> Enum.map(fn {_pair, index} -> index end)
          |> MapSet.new()

        true ->
          MapSet.new()
      end

    floors
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      base = trunc(value)

      cond do
        difference > 0 and MapSet.member?(adjust_indexes, index) -> base + 1
        difference < 0 and MapSet.member?(adjust_indexes, index) -> max(base - 1, 1)
        true -> base
      end
    end)
  end

  defp ceil_div(a, b), do: div(a + b - 1, b)

  defp create_window_with_first_tab(wt_path, window_target, tab, launch_args) do
    IO.puts("  - Tab 1: #{command_label(tab)}")
    args = launch_args ++ ["-w", window_target] ++ tab_command_args(tab)

    case run_wt_command(wt_path, args) do
      {:ok, streams} ->
        extracted = extract_window_target(streams)
        resolved = resolve_window_target(window_target, extracted)

        display_target =
          cond do
            extracted && extracted != resolved -> "#{resolved} (reported #{extracted})"
            true -> resolved
          end

        IO.puts("    ↪ targeting window #{display_target}")
        {:ok, resolved}

      {:error, reason} ->
        {:error, {:first_tab_failed, reason}}
    end
  end

  defp open_tab_with_command(wt_path, window_target, tab) do
    args = ["-w", window_target] ++ tab_command_args(tab)
    run_with_retry(fn -> run_wt_command(wt_path, args) end, @max_tab_attempts)
  end

  defp open_remaining_tabs(_wt_path, _target, []), do: :ok

  defp open_remaining_tabs(wt_path, window_target, tabs) do
    tabs
    |> Enum.with_index(2)
    |> Enum.reduce_while(:ok, fn {tab, index}, :ok ->
      IO.puts("  - Tab #{index}: #{command_label(tab)}")

      case open_tab_with_command(wt_path, window_target, tab) do
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

  defp tab_command_args(tab), do: build_tab_command_args(tab)

  defp build_tab_command_args(tab) do
    []
    |> Kernel.++(["new-tab"])
    |> maybe_put("--title", tab[:title])
    |> maybe_put("-p", tab[:profile])
    |> maybe_put("--startingDirectory", tab[:starting_directory])
    |> maybe_put_flag("--focus", truthy?(tab[:focus]))
    |> Kernel.++(command_args(tab[:command]))
  end

  defp maybe_put(args, _flag, nil), do: args
  defp maybe_put(args, _flag, ""), do: args
  defp maybe_put(args, flag, value), do: args ++ [flag, to_string(value)]

  defp maybe_put_flag(args, _flag, false), do: args
  defp maybe_put_flag(args, _flag, nil), do: args
  defp maybe_put_flag(args, flag, _), do: args ++ [flag]

  defp window_tabs(window) do
    window
    |> fetch_field(:tabs)
    |> normalize_tabs()
  end

  defp normalize_tabs(nil), do: [default_tab()]

  defp normalize_tabs(tabs) when is_list(tabs) do
    tabs
    |> Enum.map(&normalize_tab/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> [default_tab()]
      list -> list
    end
  end

  defp normalize_tabs(tab), do: normalize_tabs([tab])

  defp default_tab do
    %{
      command: nil,
      label: nil,
      title: nil,
      profile: nil,
      starting_directory: nil,
      focus: false
    }
  end

  defp normalize_tab(%{command: _, profile: _, title: _, starting_directory: _, focus: _} = tab),
    do: tab

  defp normalize_tab(nil), do: default_tab()

  defp normalize_tab(tab) when is_binary(tab) do
    default_tab() |> Map.put(:command, normalize_command(tab))
  end

  defp normalize_tab(tab) when is_map(tab) do
    command =
      tab
      |> fetch_field(:command)
      |> fallback(fetch_field(tab, :run))
      |> fallback(fetch_field(tab, :cmd))
      |> normalize_command()

    label =
      tab
      |> fetch_field(:label)
      |> fallback(fetch_field(tab, :title))
      |> normalize_optional()

    %{
      command: command,
      label: label,
      title: tab |> fetch_field(:title) |> normalize_optional(),
      profile: tab |> fetch_field(:profile) |> normalize_optional(),
      starting_directory:
        tab
        |> fetch_field(:starting_directory)
        |> fallback(fetch_field(tab, :cwd))
        |> normalize_optional(),
      focus: truthy?(fetch_field(tab, :focus))
    }
  end

  defp normalize_tab(other) do
    default_tab() |> Map.put(:command, normalize_command(other))
  end

  defp tab_summaries(tabs) do
    Enum.map(tabs, fn tab ->
      %{
        label: tab[:label],
        title: tab[:title],
        profile: tab[:profile],
        command: tab[:command]
      }
    end)
  end

  defp fallback(nil, value), do: value
  defp fallback("", value), do: value
  defp fallback(value, _), do: value

  defp normalize_command(nil), do: nil

  defp normalize_command(value) when is_binary(value) do
    value |> String.trim() |> empty_to_nil()
  end

  defp normalize_command(value) when is_atom(value) do
    value |> Atom.to_string() |> normalize_command()
  end

  defp normalize_command(value) do
    value |> to_string() |> normalize_command()
  end

  defp normalize_optional(nil), do: nil

  defp normalize_optional(value) when is_binary(value) do
    value |> String.trim() |> empty_to_nil()
  end

  defp normalize_optional(value) when is_atom(value) do
    value |> Atom.to_string() |> normalize_optional()
  end

  defp normalize_optional(value) do
    value |> to_string() |> normalize_optional()
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp truthy?(value) when is_boolean(value), do: value

  defp truthy?(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> false
      normalized -> normalized in ["1", "true", "yes", "on"]
    end
  end

  defp truthy?(value) when is_integer(value), do: value != 0
  defp truthy?(value) when is_float(value), do: value != 0.0
  defp truthy?(value) when is_atom(value), do: truthy?(Atom.to_string(value))
  defp truthy?(_), do: false

  defp window_target(window) do
    window
    |> fetch_field(:target)
    |> fallback(fetch_field(window, :name))
    |> case do
      nil -> generate_window_target()
      target -> sanitize_window_target(target)
    end
  end

  defp sanitize_window_target(target) do
    target
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, "_")
    |> case do
      "" -> generate_window_target()
      value -> value
    end
  end

  defp generate_window_target do
    "wt-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  defp resolve_window_target(original, extracted) do
    cond do
      extracted == nil -> original
      original in ["new", "last"] -> extracted
      numeric_string?(original) -> extracted
      true -> original
    end
  end

  defp numeric_string?(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.match?(~r/^[-+]?\d+$/)
  end

  defp window_uuid(window) do
    window
    |> fetch_field(:uuid)
    |> case do
      nil -> generate_uuid()
      uuid -> sanitize_uuid(uuid)
    end
  end

  defp sanitize_uuid(uuid) do
    uuid
    |> to_string()
    |> String.trim()
  end

  defp generate_uuid do
    "wt-" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  defp window_label(window, fallback_target) do
    window
    |> fetch_field(:label)
    |> fallback(fetch_field(window, :name))
    |> normalize_optional()
    |> case do
      nil -> fallback_target
      value -> value
    end
  end

  defp window_pixel_rect(window) do
    case fetch_field(window, :pixel_rect) do
      %{} = rect ->
        %{
          x: normalize_integer(fetch_field(rect, :x)),
          y: normalize_integer(fetch_field(rect, :y)),
          width: normalize_integer(fetch_field(rect, :width)),
          height: normalize_integer(fetch_field(rect, :height))
        }

      _ ->
        nil
    end
  end

  defp window_launch_switches(window) do
    []
    |> maybe_append_position(window_position(window))
    |> maybe_append_size(window_size(window))
    |> maybe_append_launch_modes(fetch_field(window, :launch_mode) || fetch_field(window, :mode))
  end

  defp window_position(window) do
    window
    |> fetch_field(:position)
    |> normalize_point()
  end

  defp window_size(window) do
    window
    |> fetch_field(:size)
    |> normalize_point()
  end

  defp normalize_point(nil), do: nil
  defp normalize_point({x, y}), do: {normalize_integer(x), normalize_integer(y)}
  defp normalize_point([x, y]), do: {normalize_integer(x), normalize_integer(y)}

  defp normalize_point(value) when is_binary(value) do
    case String.split(value, ",", parts: 2) do
      [x, y] -> {normalize_integer(x), normalize_integer(y)}
      [x] -> {normalize_integer(x), nil}
      _ -> nil
    end
  end

  defp normalize_point(%{} = map) do
    first =
      fetch_field(map, :x) ||
        fetch_field(map, :cols) ||
        fetch_field(map, :width)

    second =
      fetch_field(map, :y) ||
        fetch_field(map, :rows) ||
        fetch_field(map, :height)

    {normalize_integer(first), normalize_integer(second)}
  end

  defp normalize_point(value) do
    {normalize_integer(value), nil}
  end

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(value) when is_float(value), do: trunc(value)

  defp normalize_integer(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        nil

      trimmed ->
        case Integer.parse(trimmed) do
          {int, _} -> int
          _ -> nil
        end
    end
  end

  defp normalize_integer(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_integer()

  defp normalize_integer(value) do
    value
    |> to_string()
    |> normalize_integer()
  end

  defp maybe_append_position(args, nil), do: args

  defp maybe_append_position(args, {x, y}) do
    cond do
      is_integer(x) and is_integer(y) -> args ++ ["--pos", "#{x},#{y}"]
      is_integer(x) -> args ++ ["--pos", "#{x},"]
      is_integer(y) -> args ++ ["--pos", ",#{y}"]
      true -> args
    end
  end

  defp maybe_append_size(args, nil), do: args

  defp maybe_append_size(args, {cols, rows}) when is_integer(cols) and is_integer(rows) do
    args ++ ["--size", "#{cols},#{rows}"]
  end

  defp maybe_append_size(args, _), do: args

  defp maybe_append_launch_modes(args, nil), do: args

  defp maybe_append_launch_modes(args, modes) when is_list(modes) do
    Enum.reduce(modes, args, &maybe_append_launch_mode(&2, &1))
  end

  defp maybe_append_launch_modes(args, mode), do: maybe_append_launch_modes(args, [mode])

  defp maybe_append_launch_mode(args, mode) do
    case mode |> to_string() |> String.trim() |> String.downcase() do
      "" -> args
      "maximized" -> args ++ ["--maximized"]
      "fullscreen" -> args ++ ["--fullscreen"]
      "focus" -> args ++ ["--focus"]
      _ -> args
    end
  end

  defp fetch_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch_field(_map, _key), do: nil

  defp default_config_path do
    cond do
      path = System.get_env("WT_LAYOUT_CONFIG") ->
        {:ok, Path.expand(path)}

      File.exists?(Path.expand("config/wt_layout.exs", File.cwd!())) ->
        {:ok, Path.expand("config/wt_layout.exs", File.cwd!())}

      true ->
        :error
    end
  end

  defp parse_layout_config(path) do
    try do
      case Code.eval_file(path) do
        {value, _} ->
          case normalize_layout(value) do
            {:ok, []} ->
              :no_layout

            {:ok, windows} ->
              {:ok, windows}

            {:error, reason} ->
              {:error, {:invalid_layout, reason}}
          end
      end
    rescue
      error -> {:error, error}
    end
  end

  defp normalize_layout(%{} = config) do
    config
    |> fetch_field(:windows)
    |> case do
      nil -> {:error, :missing_windows}
      windows -> normalize_layout(windows)
    end
  end

  defp normalize_layout(nil), do: {:ok, []}

  defp normalize_layout(entries) when is_list(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.reduce({:ok, []}, fn {entry, index}, {:ok, acc} ->
      case normalize_window_entry(entry) do
        {:ok, window} -> {:ok, [window | acc]}
        {:error, reason} -> {:error, {:window, index, reason}}
      end
    end)
    |> case do
      {:ok, windows} -> {:ok, Enum.reverse(windows)}
      other -> other
    end
  end

  defp normalize_layout(_), do: {:error, :invalid_layout}

  defp normalize_window_entry(%{} = window), do: {:ok, window}

  defp normalize_window_entry(tabs) when is_list(tabs) do
    {:ok, %{tabs: tabs}}
  end

  defp normalize_window_entry(command) when is_binary(command) do
    {:ok, %{tabs: [command]}}
  end

  defp normalize_window_entry(_), do: {:error, :unsupported_window_definition}

  defp persist_window_state([], _metadata), do: :ok

  defp persist_window_state(windows, metadata) do
    metadata =
      metadata
      |> normalize_metadata()
      |> Map.put_new(:window_count, length(windows))

    state = %{
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      metadata: metadata,
      windows: windows
    }

    path = state_path()

    path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write!(path, inspect(state, limit: :infinity, pretty: true))
  rescue
    error ->
      IO.puts(:stderr, "Warning: Unable to persist window state (#{inspect(error)}).")
      :ok
  end

  defp normalize_metadata(nil), do: %{}
  defp normalize_metadata(map) when is_map(map), do: map

  defp normalize_metadata(list) when is_list(list) do
    Enum.reduce(list, %{}, fn
      {key, value}, acc -> Map.put(acc, key, value)
      other, acc -> Map.put(acc, inspect(other), other)
    end)
  end

  defp normalize_metadata(other), do: %{value: inspect(other)}

  defp state_path do
    Path.join([System.user_home!(), ".config", "wt_launcher", "windows.exs"])
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

  defp command_label(%{label: label}) when is_binary(label) and label != "", do: label
  defp command_label(%{title: title}) when is_binary(title) and title != "", do: title
  defp command_label(%{command: nil}), do: "default shell"

  defp command_label(%{command: command}) when is_binary(command) do
    "command: #{String.trim(command)}"
  end

  defp command_label(nil), do: "default shell"

  defp command_label(command) when is_binary(command) do
    "command: #{String.trim(command)}"
  end

  defp command_label(other), do: "command: #{inspect(other)}"

  defp format_error({:primary_window_failed, reason}) do
    "Failed to open the initial Windows Terminal window. " <> format_reason(reason)
  end

  defp format_error({:window_failed, window_index, reason}) do
    "Failed to open window #{window_index}. " <> format_reason(reason)
  end

  defp format_error({:tab_failed, index, reason}) do
    "Failed to open tab #{index}. " <> format_reason(reason)
  end

  defp format_error({:invalid_layout, reason}) do
    "Invalid layout configuration. " <> format_reason(reason)
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

  defp format_reason({:first_tab_failed, reason}) do
    "first tab failed: " <> format_reason(reason)
  end

  defp format_reason({:tab_failed, index, reason}) do
    "tab #{index} failed: " <> format_reason(reason)
  end

  defp format_reason({:window_failed, index, reason}) do
    "window #{index} failed: " <> format_reason(reason)
  end

  defp format_reason({:window, index, reason}) do
    "window #{index}: " <> format_reason(reason)
  end

  defp format_reason({:invalid_layout, reason}) do
    format_reason(reason)
  end

  defp format_reason(:missing_windows), do: "no :windows key present"
  defp format_reason(:unsupported_window_definition), do: "unsupported window definition"
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
end

LaunchWTErlexec.run()
