package validators

import (
	"strconv"

	"github.com/lrills/helm-unittest/unittest/snapshot"
	"github.com/lrills/helm-unittest/unittest/valueutils"
)

// MatchSnapshotValidator validate snapshot of value of Path the same as cached
type MatchSnapshotValidator struct {
	Path string
}

func (v MatchSnapshotValidator) failInfo(compared *snapshot.CompareResult, not bool) []string {
	var notAnnotation = ""
	if not {
		notAnnotation = " NOT"
	}
	snapshotFailFormat := `
Path:%s
Expected` + notAnnotation + ` to match snapshot ` + strconv.Itoa(int(compared.Index)) + `:
%s
`
	var infoToShow string
	if not {
		infoToShow = compared.CachedSnapshot
	} else {
		infoToShow = diff(compared.CachedSnapshot, compared.NewSnapshot)
	}
	return splitInfof(snapshotFailFormat, v.Path, infoToShow)
}

// Validate implement Validatable
func (v MatchSnapshotValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actual, err := valueutils.GetValueOfSetPath(manifest, v.Path)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	result := context.CompareToSnapshot(actual)

	if result.Passed != context.Negative {
		return true, []string{}
	}
	return false, v.failInfo(result, context.Negative)
}
