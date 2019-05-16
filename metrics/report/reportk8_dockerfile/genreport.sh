#!/bin/bash
# Copyright (c) 2018-2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

REPORTNAME="metricsk8s_report.pdf"

cd scripts

Rscript --slave -e "library(knitr);knit('metricsk8s_report.Rmd')"
Rscript --slave -e "library(knitr);pandoc('metricsk8s_report.md', format='latex')"

cp /scripts/${REPORTNAME} /outputdir
echo "The report, named ${REPORTNAME}, can be found in the output directory"
