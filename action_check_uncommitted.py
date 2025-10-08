#!/usr/bin/env python3
"""Check for uncommitted work in repositories."""

import subprocess
import os
from pathlib import Path


def check_uncommitted(repo_path):
    """Check if repo has uncommitted changes."""
    try:
        # Check for uncommitted changes
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.stdout.strip() != ""
    except Exception as e:
        print(f"Error checking {repo_path}: {e}")
        return False


def run(repos):
    """Run uncommitted check on all repos."""
    repos_with_changes = []

    for repo in repos:
        repo_name = Path(repo).name
        if check_uncommitted(repo):
            repos_with_changes.append(repo)
            print(f"✗ {repo_name} - has uncommitted changes")
        else:
            print(f"✓ {repo_name} - clean")

    print()
    if repos_with_changes:
        print(f"Repos with uncommitted work ({len(repos_with_changes)}):")
        for repo in repos_with_changes:
            print(f"  - {repo}")
    else:
        print("All repos are clean!")


if __name__ == "__main__":
    import json

    # Load filtered repos
    try:
        with open("repos_filtered.json", "r") as f:
            data = json.load(f)
            repos = data.get("repos", [])
    except FileNotFoundError:
        print("Error: repos_filtered.json not found. Run filter script first.")
        exit(1)

    run(repos)
