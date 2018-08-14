#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

# Description of the test:
# Use fio to gather a number of storate IO metrics.

set -e

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"

TEST_NAME="fio"
IMAGE="local-fio"
DOCKERFILE="${SCRIPT_PATH}/fio_dockerfile/Dockerfile"

OUTPUT_HOST_DIRNAME="${OUTPUT_HOST_DIRNAME:-${SCRIPT_PATH}/fio_output}"
OUTPUT_GUEST_DIRNAME="/output"

# Directory to run the test on
# This is run inside of the container
TESTDIR="${TESTDIR:-/tmp}"

init() {
	mkdir -p ${OUTPUT_HOST_DIRNAME} || true
}

main() {
	# Check tools/commands dependencies
	cmds=("awk" "docker")

	init_env
	check_cmds "${cmds[@]}"
	check_dockerfiles_images "$IMAGE" "$DOCKERFILE"

#	metrics_json_init

	local output=$(docker run --rm --runtime=$RUNTIME -v ${OUTPUT_HOST_DIRNAME}:${OUTPUT_GUEST_DIRNAME} $IMAGE)

	# Save configuration
#	metrics_json_start_array

#	metrics_json_end_array "Results"
	metrics_json_save
	clean_env
}

init
main "$@"
