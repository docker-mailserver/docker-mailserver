package validators_test

import (
	"testing"

	"github.com/lrills/helm-unittest/unittest/common"
	. "github.com/lrills/helm-unittest/unittest/validators"
	"github.com/stretchr/testify/assert"
)

func TestIsNullValidatorWhenOk(t *testing.T) {
	doc := "a:"
	manifest := makeManifest(doc)

	v := IsNullValidator{"a"}
	pass, diff := v.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})
	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestIsNullValidatorWhenNegativeAndOk(t *testing.T) {
	doc := "a: 0"
	manifest := makeManifest(doc)

	v := IsNullValidator{"a"}
	pass, diff := v.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestIsNullValidatorWhenFail(t *testing.T) {
	doc := "a: A"
	manifest := makeManifest(doc)

	v := IsNullValidator{"a"}
	pass, diff := v.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a",
		"Expected to be null, got:",
		"	A",
	}, diff)
}

func TestIsNullValidatorWhenNegativeAndFail(t *testing.T) {
	doc := "a:"
	manifest := makeManifest(doc)

	v := IsNullValidator{"a"}
	pass, diff := v.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a",
		"Expected NOT to be null, got:",
		"	null",
	}, diff)
}
