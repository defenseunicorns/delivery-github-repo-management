#!/usr/bin/env bash
set -x

# Get the directory of the currently executing script
current_dir=$(realpath $(dirname "$0"))

# Define the path to repos.txt (two levels up from the current directory)
repos_file="$(cd "$current_dir/../../" && pwd)/repos.txt"

# Check if repos.txt exists
if [ ! -f "$repos_file" ]; then
  echo "Error: repos.txt file not found at $repos_file"
  exit 1
fi

# Array of commands to check for installation
commands=("gh" "yq")
command_names=("GitHub CLI (gh)" "yq")

# Loop to check if required commands are installed
for i in "${!commands[@]}"; do
  if ! command -v "${commands[$i]}" &> /dev/null; then
    echo "${command_names[$i]} not found."
    if [[ "${commands[$i]}" == "gh" || "${commands[$i]}" == "yq" ]]; then
      echo "Installing ${command_names[$i]} via Homebrew..."
      if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed. Please install Homebrew first."
        exit 1
      fi
      # Use the corresponding command name for installation
      brew install "${commands[$i]}"
    else
      echo "Please install ${command_names[$i]} to proceed."
      exit 1
    fi
  fi
done

# build the repo settings vars

repo_settings_file="$current_dir/repo-settings.yaml"

# build apply ruleset vars

# Get list of filenames under current_dir ending with .yaml or .yml and create an array
ruleset_files=()
ruleset_subdir="rulesets"
while IFS= read -r -d $'\0' file; do
  ruleset_files+=("$file")
done < <(find "$current_dir/$ruleset_subdir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -print0)

# Build the string array with --file $file for each ruleset file
ruleset_args=()
for file in "${ruleset_files[@]}"; do
  ruleset_args+=("--file $file")
done

# Concatenate the strings with a space
ruleset_args_string=$(IFS=" "; echo "${ruleset_args[*]}")



# run the config commands

# apply top level repo settings
github-ruleset-configurator apply-repo-settings --repos-file "$repos_file" --file $repo_settings_file

# ensure top level legacy branch protection is removed
github-ruleset-configurator delete-protection --repos-file "$repos_file" --all

# apply the rulesets to the repos
github-ruleset-configurator apply --repos-file "$repos_file" $ruleset_args_string
