package validators_test

import (
	"testing"

	. "github.com/lrills/helm-unittest/unittest/validators"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/stretchr/testify/assert"
)

func TestIsKindValidatorWhenOk(t *testing.T) {
	doc := "kind: Pod"
	manifest := makeManifest(doc)

	v := IsKindValidator{"Pod"}
	pass, diff := v.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestIsKindValidatorWhenNegativeAndOk(t *testing.T) {
	doc := "kind: Service"
	manifest := makeManifest(doc)

	v := IsKindValidator{"Pod"}
	pass, diff := v.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestIsKindValidatorWhenFail(t *testing.T) {
	doc := "kind: Pod"
	manifest := makeManifest(doc)

	v := IsKindValidator{"Service"}
	pass, diff := v.Validate(&ValidateContext{
		Docs: []common.K8sManifest{manifest},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Expected kind:	Service",
		"Actual:	Pod",
	}, diff)
}

func TestIsKindValidatorWhenNegativeAndFail(t *testing.T) {
	doc := "kind: Pod"
	manifest := makeManifest(doc)

	v := IsKindValidator{"Pod"}
	pass, diff := v.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{manifest},
		Negative: true},
	)
	assert.False(t, pass)
	assert.Equal(t, []string{
		"Expected NOT to be kind:	Pod",
	}, diff)
}
