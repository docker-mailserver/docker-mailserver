package validators_test

import (
	"testing"

	. "github.com/lrills/helm-unittest/unittest/validators"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/stretchr/testify/assert"
)

var docToTestMatchRegex = `
a:
  b:
    - c: hello world
`

func TestMatchRegexValidatorWhenOk(t *testing.T) {
	manifest := makeManifest(docToTestMatchRegex)

	validator := MatchRegexValidator{"a.b[0].c", "^hello"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestMatchRegexValidatorWhenNegativeAndOk(t *testing.T) {
	manifest := makeManifest(docToTestMatchRegex)

	validator := MatchRegexValidator{"a.b[0].c", "^foo"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})
	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestMatchRegexValidatorWhenRegexCompileFail(t *testing.T) {
	manifest := common.K8sManifest{"a": "A"}

	validator := MatchRegexValidator{"a", "+"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})
	assert.False(t, pass)
	assert.Equal(t, []string{
		"Error:",
		"	error parsing regexp: missing argument to repetition operator: `+`",
	}, diff)
}

func TestMatchRegexValidatorWhenNotString(t *testing.T) {
	manifest := common.K8sManifest{"a": 123.456}

	validator := MatchRegexValidator{"a", "^foo"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Error:",
		"	expect 'a' to be a string, got:",
		"	123.456",
	}, diff)
}

func TestMatchRegexValidatorWhenMatchFail(t *testing.T) {
	manifest := makeManifest(docToTestMatchRegex)

	validator := MatchRegexValidator{"a.b[0].c", "^foo"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})
	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a.b[0].c",
		"Expected to match:	^foo",
		"Actual:	hello world",
	}, diff)
}

func TestMatchRegexValidatorWhenNegativeAndMatchFail(t *testing.T) {
	manifest := makeManifest(docToTestMatchRegex)

	validator := MatchRegexValidator{"a.b[0].c", "^hello"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a.b[0].c",
		"Expected NOT to match:	^hello",
		"Actual:	hello world",
	}, diff)
}
