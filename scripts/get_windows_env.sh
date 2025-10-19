#!/usr/bin/env bash
#
# Return the value of a Windows environment variable when invoked from WSL.
# Prints the value in Windows form (e.g. C:\Users\Name\...) without trailing CR/LF.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 VAR_NAME" >&2
  exit 64
fi

var_name=$1

# Use cmd.exe to expand the variable. Suppress stderr to avoid noisy warnings.
value=$(cmd.exe /c "echo %${var_name}%" 2>/dev/null | tr -d '\r')

if [[ -z "$value" ]]; then
  exit 1
fi

# cmd.exe returns the original token, e.g. %VAR%, if the variable is undefined.
if [[ "$value" == "%${var_name}%" ]]; then
  exit 1
fi

printf '%s\n' "$value"
