package validators_test

import (
	"testing"

	. "github.com/lrills/helm-unittest/unittest/validators"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/stretchr/testify/assert"
)

var docToTestEqual = `
a:
  b:
    - c: 123
`

func TestEqualValidatorWhenOk(t *testing.T) {
	manifest := makeManifest(docToTestEqual)
	validator := EqualValidator{"a.b[0].c", 123}

	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestEqualValidatorWhenNegativeAndOk(t *testing.T) {
	manifest := makeManifest(docToTestEqual)

	validator := EqualValidator{"a.b[0].c", 321}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestEqualValidatorWhenFail(t *testing.T) {
	manifest := makeManifest(docToTestEqual)

	validator := EqualValidator{
		"a.b[0]",
		map[interface{}]interface{}{"d": 321},
	}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a.b[0]",
		"Expected:",
		"	d: 321",
		"Actual:",
		"	c: 123",
		"Diff:",
		"	--- Expected",
		"	+++ Actual",
		"	@@ -1,2 +1,2 @@",
		"	-d: 321",
		"	+c: 123",
	}, diff)
}

func TestEqualValidatorWhenNegativeAndFail(t *testing.T) {
	manifest := makeManifest(docToTestEqual)

	v := EqualValidator{"a.b[0]", map[interface{}]interface{}{"c": 123}}
	pass, diff := v.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a.b[0]",
		"Expected NOT to equal:",
		"	c: 123",
	}, diff)
}

func TestEqualValidatorWhenWrongPath(t *testing.T) {
	manifest := makeManifest(docToTestEqual)

	v := EqualValidator{"a.b.e", map[string]int{"d": 321}}
	pass, diff := v.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Error:",
		"	can't get [\"e\"] from a non map type:",
		"	- c: 123",
	}, diff)
}
