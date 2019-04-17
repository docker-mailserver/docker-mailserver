package unittest

import (
	"fmt"
	"path/filepath"
	"time"

	"github.com/lrills/helm-unittest/unittest/snapshot"
	"k8s.io/helm/pkg/chartutil"
	"k8s.io/helm/pkg/proto/hapi/chart"
)

// testUnitCounting stores counting numbers of test unit status
type testUnitCounting struct {
	passed  uint
	failed  uint
	errored uint
}

// sprint returns string of counting result
func (counting testUnitCounting) sprint(printer *Printer) string {
	var failedLabel string
	if counting.failed > 0 {
		failedLabel = printer.danger("%d failed, ", counting.failed)
	}
	var erroredLabel string
	if counting.errored > 0 {
		erroredLabel = fmt.Sprintf("%d errored, ", counting.errored)
	}
	return failedLabel + erroredLabel + fmt.Sprintf(
		"%d passed, %d total",
		counting.passed,
		counting.passed+counting.failed,
	)
}

// testUnitCountingWithSnapshotFailed store testUnitCounting with snapshotFailed field
type testUnitCountingWithSnapshotFailed struct {
	testUnitCounting
	snapshotFailed uint
}

// totalSnapshotCounting store testUnitCounting with snapshotFailed field
type totalSnapshotCounting struct {
	testUnitCounting
	created  uint
	vanished uint
}

// TestRunner stores basic settings and testing status for running all tests
type TestRunner struct {
	Printer          *Printer
	Config           TestConfig
	suiteCounting    testUnitCountingWithSnapshotFailed
	testCounting     testUnitCounting
	chartCounting    testUnitCounting
	snapshotCounting totalSnapshotCounting
}

// Run test suites in chart in ChartPaths
func (tr *TestRunner) Run(ChartPaths []string) bool {
	allPassed := true
	start := time.Now()
	for _, chartPath := range ChartPaths {
		chart, err := chartutil.Load(chartPath)
		if err != nil {
			tr.printErroredChartHeader(err)
			tr.countChart(false, err)
			allPassed = false
			continue
		}

		testSuites, err := tr.getTestSuites(chartPath, chart.Metadata.Name, chart)
		if err != nil {
			tr.printErroredChartHeader(err)
			tr.countChart(false, err)
			allPassed = false
			continue
		}

		tr.printChartHeader(chart, chartPath)
		chartPassed := tr.runSuitesOfChart(testSuites, chart)

		tr.countChart(chartPassed, nil)
		allPassed = allPassed && chartPassed
	}
	tr.printSnapshotSummary()
	tr.printSummary(time.Now().Sub(start))
	return allPassed
}

// getTestSuites return test files of the chart which matched patterns
func (tr *TestRunner) getTestSuites(chartPath, chartRoute string, chart *chart.Chart) ([]*TestSuite, error) {
	filesSet := map[string]bool{}
	for _, pattern := range tr.Config.TestFiles {
		files, err := filepath.Glob(filepath.Join(chartPath, pattern))
		if err != nil {
			return nil, err
		}
		for _, file := range files {
			filesSet[file] = true
		}
	}

	resultSuites := make([]*TestSuite, 0, len(filesSet))
	for file := range filesSet {
		suite, err := ParseTestSuiteFile(file, chartRoute)
		if err != nil {
			tr.handleSuiteResult(&TestSuiteResult{
				FilePath:  file,
				ExecError: err,
			})
			continue
		}
		resultSuites = append(resultSuites, suite)
	}

	if tr.Config.WithSubChart {
		for _, subchart := range chart.Dependencies {
			subchartSuites, err := tr.getTestSuites(
				filepath.Join(chartPath, "charts", subchart.Metadata.Name),
				filepath.Join(chartRoute, "charts", subchart.Metadata.Name),
				subchart,
			)
			if err != nil {
				continue
			}
			resultSuites = append(resultSuites, subchartSuites...)
		}
	}

	return resultSuites, nil
}

// runSuitesOfChart runs suite files of the chart and print output
func (tr *TestRunner) runSuitesOfChart(suites []*TestSuite, chart *chart.Chart) bool {
	chartPassed := true
	for _, suite := range suites {
		snapshotCache, err := snapshot.CreateSnapshotOfSuite(suite.definitionFile, tr.Config.UpdateSnapshot)
		if err != nil {
			tr.handleSuiteResult(&TestSuiteResult{
				FilePath:  suite.definitionFile,
				ExecError: err,
			})
			continue
		}

		result := suite.Run(chart, snapshotCache, &TestSuiteResult{})
		chartPassed = chartPassed && result.Passed
		tr.handleSuiteResult(result)

		snapshotCache.StoreToFileIfNeeded()
	}

	return chartPassed
}

// handleSuiteResult print suite result and count suites and tests status
func (tr *TestRunner) handleSuiteResult(result *TestSuiteResult) {
	result.print(tr.Printer, 0)
	tr.countSuite(result)
	for _, testsResult := range result.TestsResult {
		tr.countTest(testsResult)
	}
}

//printSummary print summary footer
func (tr *TestRunner) printSummary(elapsed time.Duration) {
	summaryFormat := `
Charts:      %s
Test Suites: %s
Tests:       %s
Snapshot:    %s
Time:        %s
`
	tr.Printer.println(
		fmt.Sprintf(
			summaryFormat,
			tr.chartCounting.sprint(tr.Printer),
			tr.suiteCounting.sprint(tr.Printer),
			tr.testCounting.sprint(tr.Printer),
			tr.snapshotCounting.sprint(tr.Printer),
			elapsed.String(),
		),
		0,
	)

}

// printChartHeader print header before suite result of a chart
func (tr *TestRunner) printChartHeader(chart *chart.Chart, path string) {
	headerFormat := `
### Chart [ %s ] %s
`
	header := fmt.Sprintf(
		headerFormat,
		tr.Printer.highlight(chart.Metadata.Name),
		tr.Printer.faint(path),
	)
	tr.Printer.println(header, 0)
}

// printErroredChartHeader if chart has exexution error print header with error
func (tr *TestRunner) printErroredChartHeader(err error) {
	headerFormat := `
### ` + tr.Printer.danger("Error: ") + ` %s
`
	header := fmt.Sprintf(headerFormat, err)
	tr.Printer.println(header, 0)
}

// printSnapshotSummary print snapshot summary in footer
func (tr *TestRunner) printSnapshotSummary() {
	if tr.snapshotCounting.failed > 0 {
		snapshotFormat := `
Snapshot Summary: %s`

		summary := tr.Printer.danger("%d snapshot failed", tr.snapshotCounting.failed) +
			fmt.Sprintf(" in %d test suite.", tr.suiteCounting.snapshotFailed) +
			tr.Printer.faint(" Check changes and use `-u` to update snapshot.")

		tr.Printer.println(fmt.Sprintf(snapshotFormat, summary), 0)
	}
}

func (tr *TestRunner) countSuite(suite *TestSuiteResult) {
	if suite.Passed {
		tr.suiteCounting.passed++
	} else {
		tr.suiteCounting.failed++
		if suite.ExecError != nil {
			tr.suiteCounting.errored++
		}
		if suite.SnapshotCounting.Failed > 0 {
			tr.suiteCounting.snapshotFailed++
		}
	}
	tr.snapshotCounting.failed += suite.SnapshotCounting.Failed
	tr.snapshotCounting.passed += suite.SnapshotCounting.Total - suite.SnapshotCounting.Failed
	tr.snapshotCounting.created += suite.SnapshotCounting.Created
	tr.snapshotCounting.vanished += suite.SnapshotCounting.Vanished
}

func (tr *TestRunner) countTest(test *TestJobResult) {
	if test.Passed {
		tr.testCounting.passed++
	} else {
		tr.testCounting.failed++
		if test.ExecError != nil {
			tr.testCounting.errored++
		}
	}
}

func (tr *TestRunner) countChart(passed bool, err error) {
	if passed {
		tr.chartCounting.passed++
	} else {
		tr.chartCounting.failed++
		if err != nil {
			tr.chartCounting.errored++
		}
	}
}
