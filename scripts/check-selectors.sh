#!/usr/bin/env bash

# Set -u to error out if we use an unset variable.
# Set -o pipefail to propagate errors in a pipeline.
# Set -e to exit on any non-zero exit code.
set -uo pipefail

# Collection of repositories to check.
declare -A repositories

# is_passing is a boolean variable that is set to true if the check passes.
is_passing=true

# Define colors.
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# External dependencies: repositories, is_passing.
function check() {
  # For each repository, check if the repository exists.
  for repository in "${!repositories[@]}"; do
    repository_name=$(basename "$repository")
    if ! git ls-remote "$repository" &> /dev/null; then
      echo "Repository $repository_name does not exist."
      exit 1
    else
      # Split metric_search_scope.
      metric_search_scope=${repositories["$repository"]}
      # Split metric_search_scope into an array at colons.
      IFS=':' read -r -a metric_search_scope <<< "$metric_search_scope"
      # Set the search scope.
      search_scope="${metric_search_scope[0]}"
      # Set the prefix.
      metric_prefix="${metric_search_scope[1]}"
      # Set the selector specifier.
      selector="${metric_search_scope[2]}"
      # Display the current repository.
      echo -e "${BLUE}Checking repository $repository_name ($repository) at ./$search_scope for $metric_prefix* metrics.${NC}"
      # Check if the repository exists in the current directory.
      if [ -d "$repository_name" ]; then
        echo "Expected $repository_name to not exist in current directory, exiting."
        exit 1
      fi
      # Set the repository root.
      repository_root=$(git rev-parse --show-toplevel)
      # Clone kube-state-metrics repository.
      git clone "$repository" --depth 1 --quiet
      # Change directory to repository name.
      cd "$repository_name" || exit
      # Grep all metrics in the codebase.
      # shellcheck disable=SC2086
      find "$search_scope" -type f -not -name '*_test.go' -exec sed -nE "s/.*\"(${metric_prefix}[^\"]+)\".*/\1/p" {} \; | sort -u > metrics.txt
      # Set the paths to the alerts, lib and rules directories.
      alerts_path="$repository_root/alerts"
      lib_path="$repository_root/lib"
      rules_path="$repository_root/rules"
      # Read metrics.txt line by line.
      while IFS= read -r metric; do
        selector_misses=$(\
          grep --only-matching --color=always --line-number "$metric{[^}]*}" --directories=recurse "$alerts_path" "$lib_path" "$rules_path" |\
          grep --invert-match "$selector" \
        )
        if [ -n "$selector_misses" ]; then
          is_passing=false
          echo "The following $metric metrics are missing the $selector specifier:"
          echo "$selector_misses"
        fi
      done < metrics.txt
      # Clean artefacts, it's good to be explicit.
      rm metrics.txt
      cd .. || exit
      rm -rf "$repository_name"
    fi
  done
}

function main() {
# TODO: Currently, there are only two possible states the workflow can report: success or failure.
#  We could benefit from a third "warning" state, for cases where we observe an overlap of selectors for the same metric.
#  Ref: https://github.com/Azure/CloudShell/issues/274#issuecomment-1382412155
# ---
# List of repositories to check. The format is: "repository_url":"search_scope:metric_prefix:selector".

# * kubeSchedulerSelector
# * kubeControllerManagerSelector
# * kubeProxySelector
# * hostNetworkInterfaceSelector
# * hostMountpointSelector
# * containerfsSelector
# * kubeletSelector

# * kubeStateMetricsSelector
repositories["https://github.com/kubernetes/kube-state-metrics"]="internal/store:kube_:kubeStateMetricsSelector"
# * nodeExporterSelector
repositories["https://github.com/prometheus/node_exporter"]="collector:node_:nodeExporterSelector"
# * cadvisorSelector
repositories["https://github.com/google/cadvisor"]="metrics:(cadvisor|machine|container)_:cadvisorSelector"
# * windowsExporterSelector
repositories["https://github.com/prometheus-community/windows_exporter"]="collector:windows_:windowsExporterSelector"
# * kubeApiserverSelector
repositories["https://github.com/kubernetes/apiserver"]="pkg:apiserver_:apiserverSelector"
# Check if all metrics have appropriate selectors.
check
# Display status accordingly.
if [ "$is_passing" = true ]; then
  echo -e "${GREEN}All metrics have appropriate selectors.${NC}"
  exit 0
else
  echo -e "${YELLOW}Some metrics are missing appropriate selectors.${NC}"
  exit 1
fi
}

# Run.
main
