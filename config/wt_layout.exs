local_config_path = Path.join([File.cwd!(), "config", "wt_layout.local.exs"])

local_config =
  if File.exists?(local_config_path) do
    local_config_path |> Code.eval_file() |> elem(0)
  else
    %{}
  end

workspace_path = fn config, keys, default ->
  keys
  |> Enum.reduce(nil, fn key, acc ->
    acc || Map.get(config, key) || Map.get(config, to_string(key))
  end)
  |> case do
    nil ->
      default

    value when is_binary(value) ->
      case String.trim(value) do
        "" -> default
        path -> Path.expand(path)
      end

    _ ->
      default
  end
end

fallback = Path.expand(File.cwd!())

left_path = workspace_path.(local_config, [:left_path, :nordic_road_path], fallback)
right_path = workspace_path.(local_config, [:right_path, :snakepit_path], fallback)

[
  %{
    name: "dev-left",
    label: "Dev Left",
    position: %{x: 0, y: 0},
    size: %{cols: 110, rows: 90},
    tabs: [
      %{
        label: "Editor Shell",
        title: "editor",
        command: ~s[cd #{left_path}]
      }
    ]
  },
  %{
    name: "dev-right",
    label: "Dev Right",
    position: %{x: 1920, y: 0},
    size: %{cols: 100, rows: 90},
    tabs: [
      %{
        label: "Monitoring",
        command: ~s[cd #{right_path}]
      }
    ]
  }
]
