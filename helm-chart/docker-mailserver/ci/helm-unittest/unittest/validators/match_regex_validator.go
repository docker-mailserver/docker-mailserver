package validators

import (
	"fmt"
	"regexp"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/valueutils"
)

// MatchRegexValidator validate value of Path match Pattern
type MatchRegexValidator struct {
	Path    string
	Pattern string
}

func (v MatchRegexValidator) failInfo(actual string, not bool) []string {
	var notAnnotation = ""
	if not {
		notAnnotation = " NOT"
	}
	regexFailFormat := `
Path:%s
Expected` + notAnnotation + ` to match:%s
Actual:%s
`
	return splitInfof(regexFailFormat, v.Path, v.Pattern, actual)
}

// Validate implement Validatable
func (v MatchRegexValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actual, err := valueutils.GetValueOfSetPath(manifest, v.Path)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	p, err := regexp.Compile(v.Pattern)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	if s, ok := actual.(string); ok {
		if p.MatchString(s) != context.Negative {
			return true, []string{}
		}
		return false, v.failInfo(s, context.Negative)
	}

	return false, splitInfof(errorFormat, fmt.Sprintf(
		"expect '%s' to be a string, got:\n%s",
		v.Path,
		common.TrustedMarshalYAML(actual),
	))
}
