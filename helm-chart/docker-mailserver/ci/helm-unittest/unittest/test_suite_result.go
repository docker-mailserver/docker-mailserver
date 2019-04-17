package unittest

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/lrills/helm-unittest/unittest/snapshot"
)

// TestSuiteResult result return by TestSuite.Run
type TestSuiteResult struct {
	DisplayName      string
	FilePath         string
	Passed           bool
	ExecError        error
	TestsResult      []*TestJobResult
	SnapshotCounting struct {
		Total    uint
		Failed   uint
		Created  uint
		Vanished uint
	}
}

func (tsr TestSuiteResult) print(printer *Printer, verbosity int) {
	tsr.printTitle(printer)
	if tsr.ExecError != nil {
		printer.println(printer.highlight("- Execution Error: "), 1)
		printer.println(tsr.ExecError.Error()+"\n", 2)
		return
	}

	for _, result := range tsr.TestsResult {
		result.print(printer, verbosity)
	}
}

func (tsr TestSuiteResult) printTitle(printer *Printer) {
	var label string
	if tsr.Passed {
		label = printer.successLabel(" PASS ")
	} else {
		label = printer.dangerLabel(" FAIL ")
	}
	var pathToPrint string
	if tsr.FilePath != "" {
		pathToPrint = printer.faint(filepath.Dir(tsr.FilePath)+string(os.PathSeparator)) +
			filepath.Base(tsr.FilePath)
	}
	name := printer.highlight(tsr.DisplayName)
	printer.println(
		fmt.Sprintf("%s %s\t%s", label, name, pathToPrint),
		0,
	)
}

func (tsr *TestSuiteResult) countSnapshot(cache *snapshot.Cache) {
	tsr.SnapshotCounting.Created = cache.InsertedCount()
	tsr.SnapshotCounting.Failed = cache.FailedCount()
	tsr.SnapshotCounting.Total = cache.CurrentCount()
	tsr.SnapshotCounting.Vanished = cache.VanishedCount()
}
