package validators

import (
	"reflect"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/valueutils"
)

// IsEmptyValidator validate value of Path is empty
type IsEmptyValidator struct {
	Path string
}

func (v IsEmptyValidator) failInfo(actual interface{}, not bool) []string {
	var notAnnotation string
	if not {
		notAnnotation = " NOT"
	}

	isEmptyFailFormat := `
Path:%s
Expected` + notAnnotation + ` to be empty, got:
%s
`
	return splitInfof(isEmptyFailFormat, v.Path, common.TrustedMarshalYAML(actual))
}

// Validate implement Validatable
func (v IsEmptyValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actual, err := valueutils.GetValueOfSetPath(manifest, v.Path)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actualValue := reflect.ValueOf(actual)
	var isEmpty bool
	switch actualValue.Kind() {
	case reflect.Invalid:
		isEmpty = true
	case reflect.Array, reflect.Map, reflect.Slice:
		isEmpty = actualValue.Len() == 0
	default:
		zero := reflect.Zero(actualValue.Type())
		isEmpty = reflect.DeepEqual(actual, zero.Interface())
	}

	if isEmpty != context.Negative {
		return true, []string{}
	}
	return false, v.failInfo(actual, context.Negative)
}
