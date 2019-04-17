package validators

import "github.com/lrills/helm-unittest/unittest/common"

// IsAPIVersionValidator validate apiVersion of manifest is Of
type IsAPIVersionValidator struct {
	Of string
}

func (v IsAPIVersionValidator) failInfo(actual interface{}, not bool) []string {
	var notAnnotation string
	if not {
		notAnnotation = " NOT to be"
	}
	isAPIVersionFailFormat := "Expected" + notAnnotation + " apiVersion:%s"
	if not {
		return splitInfof(isAPIVersionFailFormat, v.Of)
	}
	return splitInfof(isAPIVersionFailFormat+"\nActual:%s", v.Of, common.TrustedMarshalYAML(actual))
}

// Validate implement Validatable
func (v IsAPIVersionValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	if kind, ok := manifest["apiVersion"].(string); (ok && kind == v.Of) != context.Negative {
		return true, []string{}
	}
	return false, v.failInfo(manifest["apiVersion"], context.Negative)
}
