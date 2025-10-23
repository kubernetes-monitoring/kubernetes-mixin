#!/usr/bin/env bash

# Set -u to error out if we use an unset variable.
# Set -o pipefail to propagate errors in a pipeline.
set -uo pipefail

# Remove kube-state-metrics directory if it exists.
rm -rf kube-state-metrics

# Clone kube-state-metrics repository.
git clone https://github.com/kubernetes/kube-state-metrics --depth 1

# Set the repository root.
repository_root=$(git rev-parse --show-toplevel)

# Change directory to kube-state-metrics.
cd kube-state-metrics || exit

# Grep all metrics in the codebase.
find internal/store -type f -not -name '*_test.go' -exec sed -nE 's/.*"(kube_[^"]+)".*/\1/p' {} \; | sort -u > metrics.txt

# Set the KSM selector specifier.
ksm_selector="kubeStateMetricsSelector"

# Set the paths to the alerts, lib and rules directories.
alerts_path="$repository_root/alerts"
lib_path="$repository_root/lib"
rules_path="$repository_root/rules"

# Read metrics.txt line by line.
while IFS= read -r metric; do
  selector_misses=$(\
    grep --only-matching --color=always --line-number "$metric{[^}]*}" --directories=recurse "$alerts_path" "$lib_path" "$rules_path" |\
    grep --invert-match "$ksm_selector" \
  )
  if [ -n "$selector_misses" ]; then
    echo "The following $metric metrics are missing the $ksm_selector specifier:"
    echo "$selector_misses"
  fi
done < metrics.txt

# Clean artefacts.
rm metrics.txt
cd .. || exit
rm -rf kube-state-metrics

# TODO: Currently, there are only two possible states the workflow can report: success or failure.
#  We could benefit from a third "warning" state, for cases where we observe an overlap of selectors for the same metric.
#  Ref: https://docs.github.com/en/actions/creating-actions/setting-exit-codes-for-actions#about-exit-codes
