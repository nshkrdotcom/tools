#!/usr/bin/env python3
"""Scan parent directory for Elixir git repositories."""

import os
import json
from pathlib import Path
import subprocess


def is_git_repo(path):
    """Check if directory is a git repository."""
    return (path / ".git").exists()


def is_elixir_repo(path):
    """Check if directory is an Elixir project."""
    return (path / "mix.exs").exists()


def scan_repos():
    """Scan all directories in parent folder for Elixir git repos."""
    parent_dir = Path("..").resolve()
    elixir_repos = []

    for item in parent_dir.iterdir():
        if item.is_dir():
            if is_git_repo(item) and is_elixir_repo(item):
                elixir_repos.append(str(item))

    elixir_repos.sort()
    return elixir_repos


def main():
    repos = scan_repos()

    # Write full config
    with open("repos.json", "w") as f:
        json.dump({"repos": repos}, f, indent=2)

    print(f"Found {len(repos)} Elixir git repositories")
    print(f"Written to repos.json")

    # Create exclude config (removing DSPex)
    excluded_repos = [r for r in repos if not r.endswith("DSPex")]
    with open("repos_exclude.json", "w") as f:
        json.dump({"repos": excluded_repos}, f, indent=2)

    print(f"Created repos_exclude.json with DSPex removed ({len(excluded_repos)} repos)")


if __name__ == "__main__":
    main()
