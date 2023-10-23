#!/usr/bin/env bash

export SKIP=go-fmt,golangci-lint,terraform_fmt,terraform_docs,terraform_checkov,terraform_tflint,renovate-config-validator

FILES="$TEMPLATE_ROOT/repo_files/*"

shopt -s dotglob  # Enable dotglob option in Bash to copy hidden files

cp -r $FILES . && \
  pre-commit install && \
  pre-commit run -a -v

shopt -u dotglob  # Disable dotglob option in Bash

echo "Done!"
