include .env

LOGLEVEL ?= INFO
BRANCH_NAME ?= git-xargs-test
COMMIT_MESSAGE?= "chore: update"
.DEFAULT_GOAL := help

# Optionally add the "-it" flag for docker run commands if the env var "CI" is not set (meaning we are on a local machine and not in github actions)
TTY_ARG :=
ifndef CI
	TTY_ARG := -it
endif

# Silent mode by default. Run `make VERBOSE=1` to turn off silent mode.
ifndef VERBOSE
.SILENT:
endif

# Idiomatic way to force a target to always run, by having it depend on this dummy target
FORCE:

.PHONY: help
help: ## Show a list of all targets
	grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sed -n 's/^\(.*\): \(.*\)##\(.*\)/\1:\3/p' \
	| column -t -s ":"

.PHONY: _create-folders
_create-folders:
	mkdir -p .cache/docker
	mkdir -p .cache/pre-commit
	mkdir -p .cache/tmp

.PHONY: docker-save-build-harness
docker-save-build-harness: _create-folders ## Pulls the build harness docker image and saves it to a tarball
	docker pull ${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION}
	docker save -o .cache/docker/build-harness.tar ${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION}

.PHONY: docker-load-build-harness
docker-load-build-harness: ## Loads the saved build harness docker image
	docker load -i .cache/docker/build-harness.tar

.PHONY: _runhooks
_runhooks: _create-folders
	docker run $(TTY_ARG) --rm \
		-v "${PWD}:/app" \
		-v "${PWD}/.cache/tmp:/tmp" \
		--workdir "/app" \
		-e "SKIP=$(SKIP)" \
		-e "PRE_COMMIT_HOME=/app/.cache/pre-commit" \
		${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION} \
		bash -c 'git config --global --add safe.directory /app && pre-commit run -a --show-diff-on-failure $(HOOK)'

.PHONY: pre-commit-all
pre-commit-all: ## Run all pre-commit hooks. Returns nonzero exit code if any hooks fail. Uses Docker for maximum compatibility
	$(MAKE) _runhooks HOOK="" SKIP=""

.PHONY: pre-commit-renovate
pre-commit-renovate: ## Run the renovate pre-commit hooks. Returns nonzero exit code if any hooks fail. Uses Docker for maximum compatibility
	$(MAKE) _runhooks HOOK="renovate-config-validator" SKIP=""

.PHONY: pre-commit-common
pre-commit-common: ## Run the common pre-commit hooks. Returns nonzero exit code if any hooks fail. Uses Docker for maximum compatibility
	$(MAKE) _runhooks HOOK="" SKIP="renovate-config-validator"

.PHONY: fix-cache-permissions
fix-cache-permissions: ## Fixes the permissions on the pre-commit cache
	docker run $(TTY_ARG) --rm -v "${PWD}:/app" --workdir "/app" -e "PRE_COMMIT_HOME=/app/.cache/pre-commit" ${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION} chmod -R a+rx .cache

.PHONY: autoformat
autoformat: ## Update files with automatic formatting tools. Uses Docker for maximum compatibility.
	$(MAKE) _runhooks HOOK="" SKIP="check-added-large-files,check-merge-conflict,detect-aws-credentials,detect-private-key,check-yaml,renovate-config-validator"

.PHONY: push-terraform
push-terraform: ## push changes to terraform repos
	./scripts/entrypoint.sh -t terraform -b $(BRANCH_NAME) --no-skip-ci --loglevel $(LOGLEVEL)

.PHONY: debug-terraform
debug-terraform: ## clone repos, run script and dry-run git-xargs
	./scripts/entrypoint.sh -t terraform -b $(BRANCH_NAME) --no-skip-ci --loglevel debug --dry-run

.PHONY: debug-keep-terraform
debug-keep-terraform: ## clone repos, run script and dry-run git-xargs, this is useful if you want to open the cloned repo and diff the changes interactively
	./scripts/entrypoint.sh -t terraform -b $(BRANCH_NAME) --no-skip-ci --loglevel debug --dry-run --keep-cloned-repositories

.PHONY: terraform-tofu-migration
terraform-tofu-migration: ## clone repos, run script and dry-run git-xargs, this is useful if you want to open the cloned repo and diff the changes interactively
	./scripts/entrypoint.sh -t terraform -b $(BRANCH_NAME) -m "$(COMMIT_MESSAGE)" --no-skip-ci --loglevel debug --executable-relative-to-repo-path -e scripts/migrate-to-tofu.sh

.PHONY: remove-repo-config-workflow
remove-repo-config-workflow: ## clone repos, run script and dry-run git-xargs, this is useful if you want to open the cloned repo and diff the changes interactively
	./scripts/entrypoint.sh -t terraform -b $(BRANCH_NAME) -m "$(COMMIT_MESSAGE)" --no-skip-ci --loglevel debug --executable-relative-to-repo-path -r ./repo_templates/terraform/alt_repotxts/repo-config-removal.txt -e scripts/remove-repo-config-workflow.sh

.PHONY: remote-renovate-migration
remote-renovate-migration: ## clone repos, run script and dry-run git-xargs
	./scripts/entrypoint.sh -t terraform -b $(BRANCH_NAME) -m "$(COMMIT_MESSAGE)" --no-skip-ci --skip-archived-repos --loglevel debug --executable-relative-to-repo-path -e scripts/migrate-to-remote-renovate.sh

.PHONY: renovate-local-debug
renovate-local: ## run renovate locally to debug
	@TOKEN=$$(gh auth token); \
	if [ -z "$$TOKEN" ]; then \
		echo "GitHub token not found"; \
		exit 1; \
	fi; \
	export RENOVATE_TOKEN=$$TOKEN; \
	export GITHUB_COM_TOKEN=$$TOKEN; \
	RENOVATE_CONFIG_FILE=./renovate.json5 \
	RENOVATE_DRY_RUN="" \
	npx renovate \
	--schedule="" \
	--require-config=ignored \
	--log-file=/tmp/renovate/log.json \
	--log-file-level=debug \
	--print-config=true \
	--platform=local \
	--github-token-warn; \
	code-insiders -r /tmp/renovate/log.json
