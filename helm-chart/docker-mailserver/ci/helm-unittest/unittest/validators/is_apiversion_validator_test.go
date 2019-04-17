package validators_test

import (
	"testing"

	"github.com/lrills/helm-unittest/unittest/common"
	. "github.com/lrills/helm-unittest/unittest/validators"
	"github.com/stretchr/testify/assert"
)

func TestIsAPiVersionValidatorWhenOk(t *testing.T) {
	doc := "apiVersion: v1"
	manifest := makeManifest(doc)

	validator := IsAPIVersionValidator{"v1"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})
	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestIsAPiVersionValidatorWhenNegativeAndOk(t *testing.T) {
	doc := "apiVersion: v1"
	manifest := makeManifest(doc)

	validator := IsAPIVersionValidator{"v2"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestIsAPIVersionValidatorWhenFail(t *testing.T) {
	doc := "apiVersion: v1"
	manifest := makeManifest(doc)

	validator := IsAPIVersionValidator{"v2"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Expected apiVersion:	v2",
		"Actual:	v1",
	}, diff)
}

func TestIsAPIVersionValidatorWhenNegativeAndFail(t *testing.T) {
	doc := "apiVersion: v1"
	manifest := makeManifest(doc)

	validator := IsAPIVersionValidator{"v1"}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Expected NOT to be apiVersion:	v1",
	}, diff)
}
