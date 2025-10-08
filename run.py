#!/usr/bin/env python3
"""Main runner script for Elixir repo management."""

import subprocess
import sys
import json
from pathlib import Path


def run_script(script_name):
    """Run a Python script and return success status."""
    try:
        result = subprocess.run([sys.executable, script_name], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error running {script_name}: {e}")
        return False


def run_action(action_module):
    """Run an action script on filtered repos."""
    try:
        with open("repos_filtered.json", "r") as f:
            data = json.load(f)
            repos = data.get("repos", [])

        # Import and run the action
        import importlib.util
        spec = importlib.util.spec_from_file_location("action", action_module)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        module.run(repos)
    except FileNotFoundError:
        print("Error: repos_filtered.json not found. Run setup first.")
        return False
    except Exception as e:
        print(f"Error running action: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("Elixir Repo Management Tool")
        print()
        print("Usage:")
        print("  python run.py scan          - Scan for Elixir repos and create configs")
        print("  python run.py filter        - Filter repos (main - excludes)")
        print("  python run.py uncommitted   - Check for uncommitted work")
        print("  python run.py placeholder   - Run placeholder action")
        print("  python run.py setup         - Run scan + filter")
        print()
        return

    command = sys.argv[1]

    if command == "scan":
        print("=== Scanning for Elixir repos ===")
        run_script("1_scan_repos.py")

    elif command == "filter":
        print("=== Filtering repos ===")
        run_script("2_filter_repos.py")

    elif command == "setup":
        print("=== Running setup (scan + filter) ===")
        if run_script("1_scan_repos.py"):
            print()
            run_script("2_filter_repos.py")

    elif command == "uncommitted":
        print("=== Checking for uncommitted work ===")
        run_action("action_check_uncommitted.py")

    elif command == "placeholder":
        print("=== Running placeholder action ===")
        run_action("action_placeholder.py")

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
