package unittest

import "fmt"

// AssertionResult result return by Assertion.Assert
type AssertionResult struct {
	Index      int
	FailInfo   []string
	Passed     bool
	AssertType string
	Not        bool
	CustomInfo string
}

func (ar AssertionResult) print(printer *Printer, verbosity int) {
	if ar.Passed {
		return
	}
	var title string
	if ar.CustomInfo != "" {
		title = ar.CustomInfo
	} else {
		var notAnnotation string
		if ar.Not {
			notAnnotation = " NOT"
		}
		title = fmt.Sprintf("- asserts[%d]%s `%s` fail", ar.Index, notAnnotation, ar.AssertType)
	}
	printer.println(printer.danger(title+"\n"), 2)
	for _, infoLine := range ar.FailInfo {
		printer.println(infoLine, 3)
	}
	printer.println("", 0)
}
