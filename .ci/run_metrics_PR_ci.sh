#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Note - no 'set -e' in this file - if one of the metrics tests fails
# then we wish to continue to try the rest.
# Finally at the end, in some situations, we explicitly exit with a
# failure code if necessary.

CURRENTDIR=$(dirname "$(readlink -f "$0")")
source "${CURRENTDIR}/../metrics/lib/common.bash"

# Set up the initial state
init() {
	metrics_onetime_init
}


# Execute metrics scripts
run() {
	pushd "$CURRENTDIR/../metrics"

	# Run the time tests
	bash time/launch_times.sh -i ubuntu -n 20 -r ${RUNTIME}

	popd
}

init
run

