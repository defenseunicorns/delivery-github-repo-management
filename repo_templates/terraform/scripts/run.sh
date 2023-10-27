#!/usr/bin/env bash
# check if rsync is installed, pre-commit is installed, and go is installed
commands=(rsync pre-commit go)
for command in "${commands[@]}"; do
  if ! command -v "$command" &> /dev/null; then
    log errpr "$command could not be found, pls install it"
    exit 1
  fi
done

# this is for the target repo's makefile to not run docker interactively
export CI=true

# Get the directory of the currently executing script
current_dir=$(dirname "$0")
# Go up four levels to the root and then into the 'scripts' directory
root_dir="$(dirname "$(dirname "$(dirname "$current_dir")")")"
# Source log.sh
. "$root_dir/scripts/log.sh"

# Items to exclude from the initial copy
declare -a excludeItems=(
  ".release-please-manifest.json"
  "Makefile"
  "test/e2e"
  "examples/complete"
)

log info "exluding copying: $(echo "${excludeItems[@]}")"

# Items to conditionally copy only if they don't exist in the target directory
declare -a conditionalItems=(
  ".release-please-manifest.json"
  "Makefile"
  "test/e2e"
  "examples/complete"
)

# Enable dotglob option in Bash to consider hidden files
shopt -s dotglob

# Build the rsync exclude flags
exclude_flags=""
for item in "${excludeItems[@]}"; do
  exclude_flags="$exclude_flags --exclude=$item"
done

log info "Running rsync from $TEMPLATE_ROOT/repo_files/ to current directory of ${PWD}"
# Copy everything except the items to exclude
rsync -av $exclude_flags "$TEMPLATE_ROOT/repo_files/" .

# Conditionally copy specific items only if they don't exist
log info "conditionally copying if it doesn't exist in the target: $(echo "${excludeItems[@]}")"
for item in "${conditionalItems[@]}"; do
  target="./$item"
  if [ ! -e "$target" ]; then
    src="$TEMPLATE_ROOT/repo_files/$item"
    rsync -av "$src" "./"
  fi
done

# Disable dotglob option in Bash
shopt -u dotglob

# Run pre-commit hooks
log info "running pre-commit hooks"
pre-commit install
pre-commit run -a -v

log info "running go mod tidy"
go mody tidy -v

log info "Done!"
