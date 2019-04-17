package validators

import (
	"fmt"
	"reflect"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/valueutils"
	yaml "gopkg.in/yaml.v2"
)

// ContainsValidator validate whether value of Path is an array and contains Content
type ContainsValidator struct {
	Path    string
	Content interface{}
}

func (v ContainsValidator) failInfo(actual interface{}, not bool) []string {
	var notAnnotation string
	if not {
		notAnnotation = " NOT"
	}
	containsFailFormat := `
Path:%s
Expected` + notAnnotation + ` to contain:
%s
Actual:
%s
`
	return splitInfof(
		containsFailFormat,
		v.Path,
		common.TrustedMarshalYAML([]interface{}{v.Content}),
		common.TrustedMarshalYAML(actual),
	)
}

// Validate implement Validatable
func (v ContainsValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	actual, err := valueutils.GetValueOfSetPath(manifest, v.Path)
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	if actual, ok := actual.([]interface{}); ok {
		found := false
		for _, ele := range actual {
			if reflect.DeepEqual(ele, v.Content) {
				found = true
			}
		}
		if found != context.Negative {
			return true, []string{}
		}
		return false, v.failInfo(actual, context.Negative)
	}

	actualYAML, _ := yaml.Marshal(actual)
	return false, splitInfof(errorFormat, fmt.Sprintf(
		"expect '%s' to be an array, got:\n%s",
		v.Path,
		string(actualYAML),
	))
}
