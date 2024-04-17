#!/usr/bin/env bash

# Copyright 2024 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script uses the logcheck tool to analyze the source code
# for proper usage of klog contextual logging.
#
# This script is based on the following reference script:
# - https://github.com/kubernetes/kubernetes/blob/master/hack/lib/util.sh
# - https://github.com/kubernetes/kubernetes/blob/master/build/common.sh

set -o errexit
set -o nounset
set -o pipefail

LOGCHECK_VERSION=${1:-0.8.1}

# This will canonicalize the path
CSI_LIB_UTIL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd -P)

# Opposite of ensure-temp-dir()
cleanup-temp-dir() {
  rm -rf "${CSI_LIB_UTIL_TEMP}"
}

# Create a temp dir that'll be deleted at the end of this bash session.
#
# Vars set:
#   CSI_LIB_UTIL_TEMP
ensure-temp-dir() {
  if [[ -z ${CSI_LIB_UTIL_TEMP-} ]]; then
    CSI_LIB_UTIL_TEMP=$(mktemp -d 2>/dev/null || mktemp -d -t csi-lib-utils.XXXXXX)
    trap_add cleanup-temp-dir EXIT
  fi
}

# Example:  trap_add 'echo "in trap DEBUG"' DEBUG
# See: http://stackoverflow.com/questions/3338030/multiple-bash-traps-for-the-same-signal
trap_add() {
  local trap_add_cmd
  trap_add_cmd=$1
  shift

  for trap_add_name in "$@"; do
    local existing_cmd
    local new_cmd

    # Grab the currently defined trap commands for this trap
    existing_cmd=$(trap -p "${trap_add_name}" |  awk -F"'" '{print $2}')

    if [[ -z "${existing_cmd}" ]]; then
      new_cmd="${trap_add_cmd}"
    else
      new_cmd="${trap_add_cmd};${existing_cmd}"
    fi

    # Assign the test. Disable the shellcheck warning telling that trap
    # commands should be single quoted to avoid evaluating them at this
    # point instead evaluating them at run time. The logic of adding new
    # commands to a single trap requires them to be evaluated right away.
    # shellcheck disable=SC2064
    trap "${new_cmd}" "${trap_add_name}"
  done
}

ensure-temp-dir
echo "Installing logcheck to temp dir: sigs.k8s.io/logtools/logcheck@v${LOGCHECK_VERSION}"
GOBIN="${CSI_LIB_UTIL_TEMP}" go install "sigs.k8s.io/logtools/logcheck@v${LOGCHECK_VERSION}"
echo "Verifing logcheck: ${CSI_LIB_UTIL_TEMP}/logcheck -check-contextual ${CSI_LIB_UTIL_ROOT}/..."
"${CSI_LIB_UTIL_TEMP}/logcheck" -check-contextual "${CSI_LIB_UTIL_ROOT}/..."
