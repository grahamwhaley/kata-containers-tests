#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

# Currently these are the CRI-O tests that are not working

declare -a skipCRIOTests=(
'test "ctr hostname env"'
'test "ctr oom"'
'test "ctr \/etc\/resolv.conf rw\/ro mode"'
'test "ctr create with non-existent command"'
'test "ctr create with non-existent command \[tty\]"'
'test "ctr update resources"'
'test "ctr resources"'
);