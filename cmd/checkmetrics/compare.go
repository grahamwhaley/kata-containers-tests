// Copyright (c) 2017-2018 Intel Corporation
//
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"errors"
	"strconv"

	log "github.com/Sirupsen/logrus"
)

// metricsCheck is a placeholder struct for us to attach the methods to and make
// it clear they belong this grouping. Maybe there is a better way?
type metricsCheck struct {
}

// reportTitleSlice returns the report table title row as a slice of strings
func (mc *metricsCheck) reportTitleSlice() []string {

	// FIXME - now we don't only check the mean, let's re-arrange the order
	// to make a little more sense.
	// Also, CoV is so much more useful than SD - let's stop printout out
	// the SD, and add instead the % gap between the Min and Max Results
	return []string{"P/F",
		"Name",
		// This is the check boundary, not the smallest value in Results
		"Floor",
		"Mean",
		// This is the check boundary, not the largest value in Results
		"Ceiling",
		"Gap",
		"Iters",
		"SD",
		"CoV"}
}

// genSummaryLine takes in all the relevant report arguments and returns
// a string slice formatted appropriately for the summary table generation
func (mc *metricsCheck) genSummaryLine(
	passed bool,
	name string,
	minval string,
	mean string,
	maxval string,
	gap string,
	iterations string,
	sd string,
	cov string) (summary []string) {

	if passed {
		summary = append(summary, "Pass")
	} else {
		summary = append(summary, "Fail")
	}

	summary = append(summary,
		name,
		minval,
		mean,
		maxval,
		gap,
		iterations,
		sd,
		cov)

	return
}

// genErrorLine takes a number of error argument strings and a pass/fail bool
// and returns a string slice formatted appropriately for the summary report.
// It exists to hide some of the inner details of just how the slice is meant
// to be formatted, such as the exact number of columns
func (mc *metricsCheck) genErrorLine(
	passed bool,
	error1 string,
	error2 string,
	error3 string) (summary []string) {

	summary = mc.genSummaryLine(passed, error1, error2, error3,
		"", "", "", "", "")
	return
}

// check takes a basefile metric record and a filled out stats struct and checks
// if the file metrics pass the metrics comparison checks.
// check returns a string slice containing the results of the check.
// The err return will be non-nil if the check fails.
func (mc *metricsCheck) checkstats(m metrics) (summary []string, err error) {
	var pass = true
	var val float64

	log.Debugf("Compare check for [%s]", m.Name)

	log.Debugf("Checking value [%s]", m.CheckType)

	//Pick out the value we are range checking depending on the
	// config. Default if not set is the "mean"
	switch m.CheckType {
	case "min":
		val = m.stats.Min

	case "max":
		val = m.stats.Max

	case "cov":
		val = m.stats.CoV

	case "sd":
		val = m.stats.SD

	case "mean":
	default:
		val = m.stats.Mean
	}

	log.Debugf(" Check minval (%f > %f)", m.MinVal, val)
	if m.stats.Mean < m.MinVal {
		log.Warnf("Failed Minval (%7f > %7f) for [%s]",
			m.MinVal, val,
			m.Name)
		pass = false
	} else {
		log.Debug("Passed")
	}

	log.Debugf(" Check maxval (%f < %f)", m.MaxVal, val)
	if val > m.MaxVal {
		log.Warnf("Failed Maxval (%7f < %7f) for [%s]",
			m.MaxVal, val,
			m.Name)
		pass = false
	} else {
		log.Debug("Passed")
	}

	if !pass {
		err = errors.New("Failed")
	}

	// Note - choosing the precision for the fields is tricky without
	// knowledge of the actual metrics tests results. For now set
	// precision to 'probably big enough', and later we may want to
	// add an annotation to the TOML baselines to give an indication of
	// expected values - or, maybe we can derive it from the min/max values
	summary = append(summary, mc.genSummaryLine(
		pass,
		m.Name,
		// Note this is the check boundary, not the smallest Result seen
		strconv.FormatFloat(m.MinVal, 'f', 3, 64),
		strconv.FormatFloat(m.stats.Mean, 'f', 3, 64),
		// Note this is the check boundary, not the largest Result seen
		strconv.FormatFloat(m.MaxVal, 'f', 3, 64),
		strconv.FormatFloat(m.Gap, 'f', 1, 64)+" %",
		strconv.Itoa(m.stats.Iterations),
		strconv.FormatFloat(m.stats.SD, 'f', 3, 64),
		strconv.FormatFloat(m.stats.CoV, 'f', 2, 64)+" %")...)

	return
}

// check takes a basefile metric record and a CSV file import record and checks
// if the CSV file metrics pass the metrics comparison checks.
// check returns a string slice containing the results of the check.
// The err return will be non-nil if the check fails.
// FIXME - once we have moved the stats inside the CSV record struct, like
// we do for JSON, then we can use the generic checkstats func and drop this
// specialised one.
func (mc *metricsCheck) check(m metrics, c csvRecord) (summary []string, err error) {
	var pass = true

	log.Debugf("Compare check for [%s]", m.Name)

	log.Debugf(" Check minval (%f > %f)", m.MinVal, c.Mean)
	if c.Mean < m.MinVal {
		log.Warnf("Failed Minval (%7f > %7f) for [%s]",
			m.MinVal, c.Mean,
			m.Name)
		pass = false
	} else {
		log.Debug("Passed")
	}

	log.Debugf(" Check maxval (%f < %f)", m.MaxVal, c.Mean)
	if c.Mean > m.MaxVal {
		log.Warnf("Failed Maxval (%7f < %7f) for [%s]",
			m.MaxVal, c.Mean,
			m.Name)
		pass = false
	} else {
		log.Debug("Passed")
	}

	if !pass {
		err = errors.New("Failed")
	}

	// Note - choosing the precision for the fields is tricky without
	// knowledge of the actual metrics tests results. For now set
	// precision to 'probably big enough', and later we may want to
	// add an annotation to the TOML baselines to give an indication of
	// expected values - or, maybe we can derive it from the min/max values
	summary = append(summary, mc.genSummaryLine(
		pass,
		m.Name,
		// Note this is the check boundary, not the smallest Result seen
		strconv.FormatFloat(m.MinVal, 'f', 3, 64),
		strconv.FormatFloat(c.Mean, 'f', 3, 64),
		// Note this is the check boundary, not the largest Result seen
		strconv.FormatFloat(m.MaxVal, 'f', 3, 64),
		strconv.FormatFloat(m.Gap, 'f', 1, 64)+" %",
		strconv.Itoa(c.Iterations),
		strconv.FormatFloat(c.SD, 'f', 3, 64),
		strconv.FormatFloat(c.CoV, 'f', 2, 64)+" %")...)

	return
}
