#!/usr/bin/env bash

#tofu migration stuff

# this is for the target repo's makefile to not run docker interactively
export CI=true

# Get the directory of the currently executing script
current_dir=$(dirname "$0")
# Go up four levels to the root and then into the 'scripts' directory
root_dir="$(dirname "$(dirname "$(dirname "$current_dir")")")"
# Source log.sh
. "$root_dir/scripts/log.sh"

# find all README.md files and replace PRE-COMMIT-TERRAFORM with PRE-COMMIT-TOFU
find . -type f -name "README.md" -exec sed -i 's/PRE-COMMIT-TERRAFORM/PRE-COMMIT-OPENTOFU/' {} +

# ripgrep to find all _test.go files that contain the pattern "terraform.Options{" and insert the line "TerraformBinary: "tofu"," after the pattern if it doesn't already exist
pattern="terraformOptions := &terraform.Options{"
insert_line="		TerraformBinary: \"tofu\","

rg -Hl -g "*_test.go" "&terraform.Options\{" . | while read -r file; do
  echo "Processing $file"
  # Check if the file contains insert_line
  if rg -q "$insert_line" "$file"; then
    echo "$file already contains $insert_line"
  else
    # Use sed to insert the line after the pattern, adjusted for macOS
    echo "Inserting $insert_line into $file"
    sed -i "/$pattern/a\\
$insert_line" "$file"
  fi
done

# sed the root Makefile to replace specific terraform commands with tofu
commands=("terraform init" "terraform_docs" "terraform_checkov")
replacements=("tofu init" "tofu_docs" "tofu_checkov")

for i in "${!commands[@]}"; do
  log info "Replacing ${commands[$i]} with ${replacements[$i]}"
  find . -maxdepth 1 -type f -name "Makefile" -exec sed -i "s/${commands[$i]}/${replacements[$i]}/g" {} \;
done

# rsync the files from the tofu_migration directory to the current directory
log info "Running rsync from $TEMPLATE_ROOT/repo_files/tofu_migration to current directory of ${PWD}"
rsync -av "$TEMPLATE_ROOT/repo_files/tofu_migration/" .

# run pre-commit autoupdate
pre-commit autoupdate
pre-commit run -a
pre-commit run -a
