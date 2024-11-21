#!/usr/bin/env bash

# this is for the target repo's makefile to not run docker interactively
export CI=true

# Get the directory of the currently executing script
current_dir=$(dirname "$0")
# Go up four levels to the root and then into the 'scripts' directory
root_dir="$(dirname "$(dirname "$(dirname "$current_dir")")")"
# Source log.sh
. "$root_dir/scripts/log.sh"

log info "Running renovate migration script"

log info "Running rsync from $TEMPLATE_ROOT/repo_files/renovate_migration to current directory of ${PWD}"
rsync -av "$TEMPLATE_ROOT/repo_files/renovate_migration/" .
