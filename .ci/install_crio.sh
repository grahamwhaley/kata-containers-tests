#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

cidir=$(dirname "$0")
source "${cidir}/lib.sh"
get_cc_versions

echo "Get CRI-O sources"
crio_repo="github.com/kubernetes-incubator/cri-o"
go get -d "$crio_repo" || true
pushd "${GOPATH}/src/${crio_repo}"
git fetch
git checkout "${crio_version}"

# Add link of go-md2man to $GOPATH/bin
GOBIN="$GOPATH/bin"
if [ ! -d "$GOBIN" ]
then
        mkdir -p "$GOBIN"
fi
ln -sf $(command -v go-md2man) "$GOBIN"

echo "Get CRI Tools"
critools_repo="github.com/kubernetes-incubator/cri-tools"
go get "$critools_repo" || true
pushd "${GOPATH}/src/${critools_repo}"
crictl_commit=$(grep "ENV CRICTL_COMMIT" "${GOPATH}/src/${crio_repo}/Dockerfile" | cut -d " " -f3)
git checkout "${crictl_commit}"
go install ./cmd/crictl
sudo install "${GOPATH}/bin/crictl" /usr/bin
popd

echo "Installing CRI-O"
make clean
make install.tools
make
make test-binaries
sudo -E PATH=$PATH sh -c "make install"
sudo -E PATH=$PATH sh -c "make install.config"

containers_config_path="/etc/containers"
echo "Copy containers policy from CRI-O repo to $containers_config_path"
sudo mkdir -p "$containers_config_path"
sudo install -m0444 test/policy.json "$containers_config_path"
popd

echo "Install runc for CRI-O"
go get -d github.com/opencontainers/runc
pushd "${GOPATH}/src/github.com/opencontainers/runc"
git checkout "$runc_version"
make
sudo -E install -D -m0755 runc "/usr/local/bin/crio-runc"
popd

crio_config_file="/etc/crio/crio.conf"
echo "Set runc as default runtime in CRI-O for trusted workloads"
sudo sed -i 's/^runtime =.*/runtime = "\/usr\/local\/bin\/crio-runc"/' "$crio_config_file"

echo "Add docker.io registry to pull images"
sudo sed -i 's/^registries = \[/registries = \[ "docker.io"/' /etc/crio/crio.conf

echo "Set Kata containers as default runtime in CRI-O for untrusted workloads"
sudo sed -i 's/default_workload_trust = "trusted"/default_workload_trust = "untrusted"/' "$crio_config_file"
sudo sed -i 's/runtime_untrusted_workload = ""/runtime_untrusted_workload = "\/usr\/local\/bin\/kata-runtime"/' "$crio_config_file"

service_path="/etc/systemd/system"
crio_service_file="${cidir}/data/crio.service"

echo "Install crio service (${crio_service_file})"
sudo install -m0444 "${crio_service_file}" "${service_path}"

echo "Reload systemd services"
sudo systemctl daemon-reload
