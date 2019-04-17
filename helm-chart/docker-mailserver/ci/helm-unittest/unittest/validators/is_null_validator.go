package validators

import (
	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/valueutils"
)

// IsNullValidator validate value of Path id kind
type IsNullValidator struct {
	Path string
}

func (v IsNullValidator) failInfo(actual interface{}, not bool) []string {
	var notAnnotation string
	if not {
		notAnnotation = " NOT"
	}

	isNullFailFormat := `
Path:%s
Expected` + notAnnotation + ` to be null, got:
%s
`
	return splitInfof(isNullFailFormat, v.Path, common.TrustedMarshalYAML(actual))
}

// Validate implement Validatable
func (v IsNullValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actual, err := valueutils.GetValueOfSetPath(manifest, v.Path)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	if actual == nil != context.Negative {
		return true, []string{}
	}
	return false, v.failInfo(actual, context.Negative)
}
