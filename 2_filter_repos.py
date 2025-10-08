#!/usr/bin/env python3
"""Filter repos by subtracting excludes from main list."""

import json


def load_repos(filename):
    """Load repos from JSON file."""
    try:
        with open(filename, "r") as f:
            data = json.load(f)
            return data.get("repos", [])
    except FileNotFoundError:
        print(f"Error: {filename} not found. Run 1_scan_repos.py first.")
        return []


def filter_repos():
    """Get repos from main list minus excludes."""
    main_repos = load_repos("repos.json")
    exclude_repos = load_repos("repos_exclude.json")

    # Subtract: repos in main but NOT in exclude
    filtered = [r for r in main_repos if r not in exclude_repos]
    return filtered


def main():
    filtered = filter_repos()

    # Save filtered list
    with open("repos_filtered.json", "w") as f:
        json.dump({"repos": filtered}, f, indent=2)

    print(f"Filtered repos: {len(filtered)}")
    for repo in filtered:
        print(f"  - {repo}")


if __name__ == "__main__":
    main()
