package validators

import "github.com/lrills/helm-unittest/unittest/common"

// IsKindValidator validate kind of manifest is Of
type IsKindValidator struct {
	Of string
}

func (v IsKindValidator) failInfo(actual interface{}, not bool) []string {
	var notAnnotation string
	if not {
		notAnnotation = " NOT to be"
	}
	isKindFailFormat := "Expected" + notAnnotation + " kind:%s"
	if not {
		return splitInfof(isKindFailFormat, v.Of)
	}
	return splitInfof(isKindFailFormat+"\nActual:%s", v.Of, common.TrustedMarshalYAML(actual))
}

// Validate implement Validatable
func (v IsKindValidator) Validate(context *ValidateContext) (bool, []string) {
	manifest, err := context.getManifest()
	if err != nil {
		return false, splitInfof(errorFormat, err.Error())
	}

	if kind, ok := manifest["kind"].(string); (ok && kind == v.Of) != context.Negative {
		return true, []string{}
	}
	return false, v.failInfo(manifest["kind"], context.Negative)
}
