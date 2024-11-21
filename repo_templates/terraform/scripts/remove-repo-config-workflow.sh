#!/usr/bin/env bash
set -x

find .github/workflows -name "repo-config.yml" -exec rm -f {} \;

echo "yay"
