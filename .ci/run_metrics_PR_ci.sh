#!/bin/bash
# Copyright (c) 2017-2018 Intel Corporation
# 
# SPDX-License-Identifier: Apache-2.0

# Note - no 'set -e' in this file - if one of the metrics tests fails
# then we wish to continue to try the rest.
# Finally at the end, in some situations, we explicitly exit with a
# failure code if necessary.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/../metrics/lib/common.bash"
RESULTS_DIR=${SCRIPT_DIR}/../metrics/results
CHECKMETRICS_DIR=${SCRIPT_DIR}/../cmd/checkmetrics

# Set up the initial state
init() {
	metrics_onetime_init
}


# Execute metrics scripts
run() {
	pushd "$SCRIPT_DIR/../metrics"

	# Run the time tests
	bash time/launch_times.sh -i ubuntu -n 20 -r ${RUNTIME}

	popd
}

# Check the results
check() {
	if [ -n "${METRICS_CI}" ]; then
		# Ensure we have the latest checkemtrics
		pushd "$CHECKMETRICS_DIR"
		sudo make install
		popd

		checkmetrics --basefile /etc/checkmetrics/checkmetrics-json-$(uname -n).toml --metricsdir ${RESULTS_DIR}
		cm_result=$?
		if [ ${cm_result} != 0 ]; then
			echo "checkmetrics FAILED (${cm_result})"
			exit ${cm_result}
		fi
	fi
}

init
run
check
