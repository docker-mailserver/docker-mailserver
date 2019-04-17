package validators

import (
	"fmt"
	"strings"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/snapshot"
	"github.com/pmezard/go-difflib/difflib"
)

// SnapshotComparer provide CompareToSnapshot utility to validator
type SnapshotComparer interface {
	CompareToSnapshot(content interface{}) *snapshot.CompareResult
}

// ValidateContext the context passed to validators
type ValidateContext struct {
	Docs     []common.K8sManifest
	Index    int
	Negative bool
	SnapshotComparer
}

func (c *ValidateContext) getManifest() (common.K8sManifest, error) {
	if len(c.Docs) <= c.Index {
		return nil, fmt.Errorf("documentIndex %d out of range", c.Index)
	}
	return c.Docs[c.Index], nil
}

// Validatable all validators must implement Validate method
type Validatable interface {
	Validate(context *ValidateContext) (bool, []string)
}

// splitInfof split multi line string into array of string
func splitInfof(format string, replacements ...string) []string {
	intentedFormat := strings.Trim(format, "\t\n ")
	indentedReplacements := make([]interface{}, len(replacements))
	for i, r := range replacements {
		indentedReplacements[i] = "\t" + strings.Trim(
			strings.Replace(r, "\n", "\n\t", -1),
			"\n\t ",
		)
	}
	return strings.Split(
		fmt.Sprintf(intentedFormat, indentedReplacements...),
		"\n",
	)
}

// diff return diff result for assertion
func diff(expected string, actual string) string {
	diff, _ := difflib.GetUnifiedDiffString(difflib.UnifiedDiff{
		A:        difflib.SplitLines(expected),
		B:        difflib.SplitLines(actual),
		FromFile: "Expected",
		FromDate: "",
		ToFile:   "Actual",
		ToDate:   "",
		Context:  1,
	})
	return diff
}

const errorFormat = `
Error:
%s
`
