#!/usr/bin/env bash

set -e
trap 'echo ❌ exit at ${0}:${LINENO}, command was: ${BASH_COMMAND} 1>&2' ERR

echo -e "Starting script with $# arguments: $@\n"


SCRIPT_PATH=$(dirname "$0")
# up one level from SCRIPT_PATH
REPO_ROOT=$(realpath "$(dirname "$SCRIPT_PATH")")

# script help message
function help {
  cat <<EOF
usage: $(basename "$0") <arguments>
-h|--help                - print this help message and exit
-t|--template            - (required) repo_template directory to target
-b|--branch              - (required) branch name to target for each repo
-r|--repositoryfile      - (optional) path to repos.txt file to determine which repos to target, defaults to the one in the repo_template directory
-m|--message             - (required) commit message to use for each repo
--loglevel               - (optional) loglevel for git-xargs process
-e|--executable          - (required) executable to use for git-xargs process, this needs to be the full path to the executable
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
      BRANCH_NAME=$2
      shift 2
    else
      echo "Error: Argument for $1 is missing" >&2
      help
      exit 1
    fi
    ;;
  # repository file optional argument
  -r | --repository-file)
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      REPOSITORY_FILE=$2
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
  # unsupported flags
  -* | --*=)
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
    [EXECUTABLE]="-e|--executable\n"
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
REPOSITORY_FILE=${REPOSITORY_FILE:-"${REPO_ROOT}/repo_templates/${TEMPLATE}/repos.txt"} # default to repos.txt in repo_template directory
COMMIT_MESSAGE=${COMMIT_MESSAGE:-"Update ${BRANCH_NAME} branch from delivery-github-repo-management"}
LOGLEVEL=${LOGLEVEL:-"INFO"}


