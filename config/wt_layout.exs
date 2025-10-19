[
  %{
    name: "dev-left",
    label: "Dev Left",
    position: %{x: 0, y: 0},
    size: %{cols: 220, rows: 90},
    launch_mode: ["focus"],
    tabs: [
      %{
        label: "Editor Shell",
        title: "editor",
        command: ~s[echo "left window: editor shell"]
      },
      %{
        label: "Tests",
        command: ~s[echo "left window: tests lane"]
      }
    ]
  },
  %{
    name: "dev-right",
    label: "Dev Right",
    position: %{x: 1920, y: 0},
    size: %{cols: 180, rows: 90},
    tabs: [
      %{
        label: "Monitoring",
        command: ~s[echo "right window: monitoring"]
      },
      %{
        label: "Scratch",
        command: nil
      }
    ]
  }
]
