#!/bin/bash
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -x
set -e

GLOBOPTS="--fallocate=none"

for blocksize in 128 256 512 1k 2k 4k 8k 16k 32k 64k; do
	fio ${GLOBOPTS} --blocksize=${blocksize} --output=/output/fio-rand-RW-${blocksize}.json --output-format=json /scripts/fio-rand-RW.job
done
