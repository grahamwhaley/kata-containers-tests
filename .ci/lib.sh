#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
# Copyright (c) 2018 ARM Limited
#
# SPDX-License-Identifier: Apache-2.0
#

export KATA_RUNTIME=${KATA_RUNTIME:-kata-runtime}

# How long do we wait for docker to perform a task before we
# timeout with the presumption it has hung.
# Docker itself has a 10s timeout, so make our timeout longer
# than that. Measured in seconds by default (see timeout(1) for
# more formats).
export KATA_DOCKER_TIMEOUT=30

tests_repo="${tests_repo:-github.com/kata-containers/tests}"
lib_script="${GOPATH}/src/${tests_repo}/lib/common.bash"
source "${lib_script}"

# If we fail for any reason a message will be displayed
die() {
	msg="$*"
	echo "ERROR: $msg" >&2
	exit 1
}

info() {
	echo -e "INFO: $*"
}

# If CI is defined, execute the command arguments under chronic
# with a 'ticker heartbeat echo' so the CI system does not timeout
# due to inactivity.
# Otherwise, run the commands directly.
ci_chronic() {
	CI=${CI:-false}
	if [ "$CI" == true ]; then
		# If we ever get the kata_chronic.sh script landed in the
		# .ci dir, then call that here instead of open coding it.
		local cmdLine=$@

		eval chronic "${cmdLine[@]}" &
		local cmdPid="$!"

		(
			# Catch death and exit cleanly
			finish() {
				exit 0
			}

			local sleepval=10
			local echoval=60
			local count=0
			trap finish QUIT

			while true; do
				printf ".";sleep ${sleepval};
				((count+=${sleepval}))
				printf $count
				((count%${echoval} == 0)) && printf ":\n" && count=0
			done
		)&

		local printerPid="$!"

		wait "$cmdPid"
		local ret=$?
		printf "\n"
		kill -QUIT "$printerPid"
		# Wait for it to die, which silences the 'Terminated' text
		# we'd otherwise get printed, which messes up the logs.
		wait "$printerPid"


		# And return the exit code from the sub-command
		return "$ret"
	else
		eval $@
	fi
}

function build_version() {
	github_project="$1"
	make_target="$2"
	version="$3"

	[ -z "${version}" ] && die "need version to build"

	project_dir="${GOPATH}/src/${github_project}"

	[ -d "${project_dir}" ] || go get -d "${github_project}" || true

	pushd "${project_dir}"

	if [ "$version" != "HEAD" ]; then
		info "Using ${github_project} version ${version}"
		git checkout -b "${version}" "${version}"
	fi

	info "Building ${github_project}"
	if [ ! -f Makefile ]; then
		if [ -f autogen.sh ]; then
			info "Run autogen.sh to generate Makefile"
			bash -f autogen.sh
		fi
	fi

	if [ -f Makefile ]; then
		make ${make_target}
	else
		# install locally (which is what "go get" does by default)
		go install ./...
	fi

	popd
}

function build() {
	github_project="$1"
	make_target="$2"

	build_version "${github_project}" "${make_target}" "HEAD"
}

function build_and_install() {
	github_project="$1"
	make_target="$2"
	build "${github_project}" "${make_target}"
	pushd "${GOPATH}/src/${github_project}"
	info "Installing ${github_project}"
	sudo -E PATH="$PATH" KATA_RUNTIME="${KATA_RUNTIME}" make install
	popd
}

function install_yq() {
	GOPATH=${GOPATH:-${HOME}/go}
	local yq_path="${GOPATH}/bin/yq"
	local yq_pkg="github.com/mikefarah/yq"
	[ -x  "${GOPATH}/bin/yq" ] && return

	read -r -a sysInfo <<< "$(uname -sm)"

	case "${sysInfo[0]}" in
	"Linux" | "Darwin")
		goos="${sysInfo[0],}"
		;;
	"*")
		die "OS ${sysInfo[0]} not supported"
		;;
	esac

	case "${sysInfo[1]}" in
	"aarch64")
		goarch=arm64
		;;
	"ppc64le")
		goarch=ppc64le
		;;
	"x86_64")
		goarch=amd64
		;;
	"s390x")
		goarch=s390x
		;;
	"*")
		die "Arch ${sysInfo[1]} not supported"
		;;
	esac

	mkdir -p "${GOPATH}/bin"

	# Workaround to get latest release from github (to not use github token).
	# Get the redirection to latest release on github.
	yq_latest_url=$(curl -Ls -o /dev/null -w %{url_effective} "https://${yq_pkg}/releases/latest")
	# The redirected url should include the latest release version
	# https://github.com/mikefarah/yq/releases/tag/<VERSION-HERE>
	yq_version=$(basename "${yq_latest_url}")

	local yq_url="https://${yq_pkg}/releases/download/${yq_version}/yq_${goos}_${goarch}"
	curl -o "${yq_path}" -LSs ${yq_url}
	chmod +x ${yq_path}

	if ! command -v "${yq_path}" >/dev/null; then
		die "Cannot not get ${yq_path} executable"
	fi
}

function get_dep_from_yaml_db(){
	local versions_file="$1"
	local dependency="$2"

	[ ! -f "$versions_file" ] && die "cannot find $versions_file"

	install_yq >&2

	result=$("${GOPATH}/bin/yq" read "$versions_file" "$dependency")
	[ "$result" = "null" ] && result=""
	echo "$result"
}

function get_version(){
	dependency="$1"
	GOPATH=${GOPATH:-${HOME}/go}
	runtime_repo="github.com/kata-containers/runtime"
	runtime_repo_dir="$GOPATH/src/${runtime_repo}"
	versions_file="${runtime_repo_dir}/versions.yaml"
	mkdir -p "$(dirname ${runtime_repo_dir})"
	[ -d "${runtime_repo_dir}" ] ||  git clone --quiet https://${runtime_repo}.git "${runtime_repo_dir}"

	get_dep_from_yaml_db "${versions_file}" "${dependency}"
}

function get_test_version(){
	local dependency="$1"

	local db
	local cidir

	# directory of this script, not the caller
	local cidir=$(dirname "${BASH_SOURCE[0]}")

	db="${cidir}/../versions.yaml"

	get_dep_from_yaml_db "${db}" "${dependency}"
}

function check_gopath() {
	# Verify GOPATH is set
	if [ -z "$GOPATH" ]; then
		export GOPATH=$(go env GOPATH)
	fi
}

function waitForProcess(){
        wait_time="$1"
        sleep_time="$2"
        cmd="$3"
        while [ "$wait_time" -gt 0 ]; do
                if eval "$cmd"; then
                        return 0
                else
                        sleep "$sleep_time"
                        wait_time=$((wait_time-sleep_time))
                fi
        done
        return 1
}

kill_stale_process()
{
	clean_env
	extract_kata_env
	stale_process_union=( "${stale_process_union[@]}" "${PROXY_PATH}" "${HYPERVISOR_PATH}" "${SHIM_PATH}" )
	for stale_process in "${stale_process_union[@]}"; do
		local pids=$(pgrep -d ' ' -f "${stale_process}")
		if [ -n "$pids" ]; then
			sudo kill -9 ${pids} || true
		fi
	done
}

delete_stale_docker_resource()
{
	local docker_status=false
	# check if docker service is running
	systemctl is-active --quiet docker
	if [ $? -eq 0 ]; then
		docker_status=true
		sudo systemctl stop docker
	fi
	# before removing stale docker dir, you should umount related resource
	for stale_docker_mount_point in "${stale_docker_mount_point_union[@]}"; do
		local mount_point_union=$(mount | grep "${stale_docker_mount_point}" | awk '{print $3}')
		if [ -n "${mount_point_union}" ]; then
			while IFS='$\n' read mount_point; do
				sudo umount "${mount_point}"
			done <<< "${mount_point_union}"
		fi
	done
	# remove stale docker dir
	for stale_docker_dir in "${stale_docker_dir_union[@]}"; do
		if [ -d "${stale_docker_dir}" ]; then
			sudo rm -rf "${stale_docker_dir}"
		fi
	done
	[ "${docker_status}" = true ] && sudo systemctl restart docker
}

delete_stale_kata_resource()
{
	for stale_kata_dir in "${stale_kata_dir_union[@]}"; do
		if [ -d "${stale_kata_dir}" ]; then
			sudo rm -rf "${stale_kata_dir}"
		fi
	done
}

gen_clean_arch() {
	# Set up some vars
	stale_process_union=( "docker-containerd-shim" )
	#docker supports different storage driver, such like overlay2, aufs, etc.
	docker_storage_driver=$(timeout ${KATA_DOCKER_TIMEOUT} docker info --format='{{.Driver}}')
	stale_docker_mount_point_union=( "/var/lib/docker/containers" "/var/lib/docker/${docker_storage_driver}" )
	stale_docker_dir_union=( "/var/lib/docker" )
	stale_kata_dir_union=( "/var/lib/vc" "/run/vc" )

	info "kill stale process"
	kill_stale_process
	info "delete stale docker resource under ${stale_docker_dir_union[@]}"
	delete_stale_docker_resource
	info "delete stale kata resource under ${stale_kata_dir_union[@]}"
	delete_stale_kata_resource
	info "Remove installed kata packages"
	${GOPATH}/src/${tests_repo}/cmd/kata-manager/kata-manager.sh remove-packages
	info "Remove installed kubernetes packages and configuration"
	if [ "$ID" == ubuntu ]; then
		sudo rm -rf /etc/systemd/system/kubelet.service.d
		sudo apt-get purge kubeadm kubelet kubectl -y
	fi
}

