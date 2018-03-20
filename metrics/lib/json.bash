#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
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

# common JSON routines used by metrics tests to register and save
# JSON format results

# The JSON lib initialisation routine
#
# arg1 - the overall 'name' of the test

declare -a json_result_array
declare -a json_array_array


# Generate a timestamp in nanoseconds since 1st Jan 1970
timestamp_ns() {
	local t
	local s
	local n
	local ns

	t="$(date +%-s:%-N)"
	s=$(echo $t | awk -F ':' '{print $1}')
	n=$(echo $t | awk -F ':' '{print $2}')
	ns=$(( (s * 1000000000) + n ))

	echo $ns
}

metrics_json_init() {

	# Clear out any previous results
	json_result_array=()

	echo "Starting JSON for [${TEST_NAME}]"

	json_filename=${RESULT_DIR}/$(echo ${TEST_NAME} | sed 's/[ \/]/-/g').json

	local json="$(cat << EOF
	"env" : {
		"Runtime": "$RUNTIME_PATH",
		"RuntimeVersion": "$RUNTIME_VERSION",
		"Hypervisor": "$HYPERVISOR_PATH",
		"HypervisorVersion": "$HYPERVISOR_VERSION",
		"Proxy": "$PROXY_PATH",
		"ProxyVersion": "$PROXY_VERSION",
		"Shim": "$SHIM_PATH",
		"ShimVersion": "$SHIM_VERSION"
	}
EOF
)"

	metrics_json_add_fragment "$json"

	local json="$(cat << EOF
	"date" : {
		"ns": $(timestamp_ns),
		"Date": "$(date "+%Y-%m-%d %T %z")"
	}
EOF
)"
	metrics_json_add_fragment "$json"

}

metrics_json_save() {
	echo "Saving JSON results for [${TEST_NAME}] in [${json_filename}]"

	if [ ! -d ${RESULT_DIR} ];then
		mkdir -p ${RESULT_DIR}
	fi

	local maxelem=$(( ${#json_result_array[@]} - 1 ))
	echo "Process ${#json_result_array[@]} elements (max $maxelem)"
	local json="$(cat << EOF
{
$(for index in $(seq 0 $maxelem); do
	if (( index != maxelem )); then
		echo "${json_result_array[$index]},"
	else
		echo "${json_result_array[$index]}"
	fi
done)
}
EOF
)"

	echo "$json" > $json_filename
}

metrics_json_add_fragment() {
	local data=$1

	# Place on end of array
	echo "  JSON adding [$data]"
	json_result_array[${#json_result_array[@]}]="$data"
	echo "  JSON now has ${#json_result_array[@]} elements"
}

metrics_json_start_array() {
	echo "Start new json array"
	json_array_array=()
}

metrics_json_add_array_element() {
	local data=$1

	# Place on end of array
	echo "  JSON adding array element [$data]"
	json_array_array[${#json_array_array[@]}]="$data"
}

metrics_json_end_array() {
	local name=$1

	echo "  JSON save array [$name]"

	local maxelem=$(( ${#json_array_array[@]} - 1 ))
	local json="$(cat << EOF
	"$name": [
		$(for index in $(seq 0 $maxelem); do
			if (( index != maxelem )); then
				echo "${json_array_array[$index]},"
			else
				echo "${json_array_array[$index]}"
			fi
		done)
	]
EOF
)"

	# And save that to the top level
	metrics_json_add_fragment "$json"

	echo "  JSON save array generated [$json]"
}
