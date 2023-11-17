#!/usr/bin/env bash

# Get the directory of the currently executing script
current_dir=$(dirname "$0")
# Go up four levels to the root and then into the 'scripts' directory
root_dir="$(dirname "$(dirname "$(dirname "$current_dir")")")"
# Source log.sh
. "$root_dir/scripts/log.sh"

# Use find to get all non-hidden files, then use sed to replace "-uds-" with ""
find . \( ! -regex '.*/\..*' \) -type f -exec sed -i 's/-uds-/-/g' {} +

# Get the URL of the remote origin
repo_url=$(git config --get remote.origin.url)

# Extract the repository name from the URL
repo_name=$(basename -s .git "${repo_url}")

# Check if the repository name contains "-uds", if so, rename it
if [[ $repo_name == *"-uds"* ]]; then
  log info "The repository name contains '-uds-': $repo_name"

  # Remove "-uds" from the repository name
  new_repo_name=${repo_name//-uds/}
  log info "Renaming the repository to: $new_repo_name"

  # Rename the repository
  gh repo rename $new_repo_name -y
fi

# Run go mod tidy to clean up Go dependencies
go mod tidy -v
pre-commit install
pre-commit run -a -v

log info "Done!"
