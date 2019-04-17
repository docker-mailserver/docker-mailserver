package validators

import (
	"reflect"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/valueutils"
)

// EqualValidator validate whether the value of Path equal to Value
type EqualValidator struct {
	Path  string
	Value interface{}
}

func (a EqualValidator) failInfo(actual interface{}, not bool) []string {
	var notAnnotation string
	if not {
		notAnnotation = " NOT to equal"
	}
	failFormat := `
Path:%s
Expected` + notAnnotation + `:
%s`

	expectedYAML := common.TrustedMarshalYAML(a.Value)
	if not {
		return splitInfof(failFormat, a.Path, expectedYAML)
	}

	actualYAML := common.TrustedMarshalYAML(actual)
	return splitInfof(
		failFormat+`
Actual:
%s
Diff:
%s
`,
		a.Path,
		expectedYAML,
		actualYAML,
		diff(expectedYAML, actualYAML),
	)
}

// Validate implement Validatable
func (a EqualValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actual, err := valueutils.GetValueOfSetPath(manifest, a.Path)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	if reflect.DeepEqual(a.Value, actual) == context.Negative {
		return false, a.failInfo(actual, context.Negative)
	}
	return true, []string{}
}
