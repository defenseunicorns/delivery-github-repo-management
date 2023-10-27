#!/usr/bin/env bash
# this script is an entrypoint script to pass parameters to the run.sh scripts under the repo_template directory

. log.sh;

set -e
trap 'echo ❌ exit at ${0}:${LINENO}, command was: ${BASH_COMMAND} 1>&2' ERR

echo -e "Starting script with $# arguments: $@\n"



# Check if GITHUB_OAUTH_TOKEN is empty
if [ -z "${GITHUB_OAUTH_TOKEN}" ]; then
  # Attempt to set GITHUB_OAUTH_TOKEN using gh auth token
  GITHUB_OAUTH_TOKEN=$(gh auth token)

  # Check if the command succeeded
  if [ $? -eq 0 ]; then
    # If the command succeeded, export GITHUB_OAUTH_TOKEN
    export GITHUB_OAUTH_TOKEN
  else
    # If the command failed, print an error message and exit
    log error "Error: GITHUB_OAUTH_TOKEN environment variable is not set and is required by git-xargs"
    exit 1
  fi
fi

# get repo root path
REPO_ROOT=$(realpath "$(dirname "$(dirname "$0")")")
export REPO_ROOT

# script help message
function help {
  cat <<EOF
usage: $(basename "$0") <arguments>
-h|--help                   - print this help message and exit
-t|--template               - (required) repo_template directory to target
-b|--branch                 - (required) branch name to target for each repo
-r|--repos-file             - (optional) path to repos.txt file to determine which repos to target, defaults to the one in the repo_template directory
-m|--message                - (required) commit message to use for each repo
-e|--executable             - (optional) executable to use for git-xargs process, this needs to be the full path to the executable, defaults to the run.sh script in the repo_template relative to the template
--no-skip-ci                - (optional) do not skip CI for each repo
--draft                     - (optional) create a draft PR for each repo
--dry-run                   - (optional) do not actually run the git-xargs process, just output the command that would be run
--keep-cloned-repositories  - (optional) do not delete the cloned local repositories after the git-xargs process is complete
--loglevel                  - (optional) loglevel for git-xargs process
EOF
}

#
# cli parsing
#

# if "$#" is 0, then print help and exit
if [ "$#" -eq 0 ]; then
  help
  exit 1
fi

PARAMS=""
while (("$#")); do
  case "$1" in
  # template directory required argument
  -t | --template)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      TEMPLATE=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  # branch name required argument
  -b | --branch)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      export BRANCH_NAME=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  # repos file optional argument
  -r | --repos-file)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      REPOS_FILE=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  # commit message required argument
  -m | --message)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      COMMIT_MESSAGE=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  # loglevel optional argument
  --loglevel)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      LOGLEVEL=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  # executable required argument
  -e | --executable)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      EXECUTABLE=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  --no-skip-ci)
    SKIP_CI=false
    shift
    ;;
  --draft)
    DRAFT=true
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --keep-cloned-repositories)
    KEEP_CLONED_REPOSITORIES=true
    shift
    ;;
  # help message
  -h | --help)
    help
    exit 0
    ;;
  # unsupported flags
  -*)
    echo "Error: Unsupported flag $1" >&2
    help
    exit 1
    ;;
  # preserve positional arguments
  *)
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done

# Check that all required arguments are set
declare -A required_args=(
    [TEMPLATE]="-t|--template\n"
    [BRANCH_NAME]="-b|--branch\n"
)

error_msg="Error: Missing required arguments:\n"
missing_args=0

for var in "${!required_args[@]}"; do
    if [ -z "${!var}" ]; then
        error_msg="$error_msg ${required_args[$var]}"
        missing_args=1
    fi
done

if [ $missing_args -eq 1 ]; then
    echo -e "$error_msg" >&2
    help
    exit 1
fi

# set helper vars
export TEMPLATE_ROOT="${REPO_ROOT}/repo_templates/${TEMPLATE}"
REPOS_FILE=${REPOS_FILE:-"$TEMPLATE_ROOT/repos.txt"} # default to repos.txt in repo_template directory
COMMIT_MESSAGE=${COMMIT_MESSAGE:-"ci: Update ${BRANCH_NAME} branch from delivery-github-repo-management"}
LOGLEVEL=${LOGLEVEL:-"INFO"}
RUN_SCRIPT="${RUN_SCRIPT:-"$TEMPLATE_ROOT/scripts/run.sh"}"
EXECUTABLE=${EXECUTABLE:-"${RUN_SCRIPT}"}
SKIP_CI=${SKIP_CI:-"true"}
DRAFT=${DRAFT:-"false"}

main(){
  # Initialize arguments string
  args=(
    --repos "${REPOS_FILE}"
    --branch-name "${BRANCH_NAME}"
    --commit-message "${COMMIT_MESSAGE}"
    --loglevel "${LOGLEVEL}"
  )

  # Conditionally add other arguments
  if [[ "${SKIP_CI}" == "false" ]]; then
    args+=(--no-skip-ci)
  fi

  if [[ "${DRAFT}" == "true" ]]; then
    args+=(--draft)
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    args+=(--dry-run)
  fi

  if [[ "$KEEP_CLONED_REPOSITORIES" == "true" ]]; then
    args+=(--keep-cloned-repositories)
  fi

  # Call git-xargs with the constructed arguments
  # executable has to go last
  # custom version of git-xargs for commit signing.. build here: https://github.com/zack-is-cool/git-xargs/tree/feat/add-commit-signing
  git-xargs "${args[@]}" "$EXECUTABLE"
}

main
