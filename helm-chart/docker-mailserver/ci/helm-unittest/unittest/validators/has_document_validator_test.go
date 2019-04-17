package validators_test

import (
	"testing"

	"github.com/lrills/helm-unittest/unittest/common"
	. "github.com/lrills/helm-unittest/unittest/validators"
	"github.com/stretchr/testify/assert"
)

func TestHasDocumentsValidatorOk(t *testing.T) {
	data := common.K8sManifest{}

	validator := HasDocumentsValidator{2}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{data, data},
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestHasDocumentsValidatorWhenNegativeAndOk(t *testing.T) {
	data := common.K8sManifest{}

	validator := HasDocumentsValidator{2}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{data},
		Negative: true,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)
}

func TestHasDocumentsValidatorWhenFail(t *testing.T) {
	data := common.K8sManifest{}

	validator := HasDocumentsValidator{1}
	pass, diff := validator.Validate(&ValidateContext{
		Docs: []common.K8sManifest{data, data},
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Expected documents count:	1",
		"Actual:	2",
	}, diff)
}

func TestHasDocumentsValidatorWhenNegativeAndFail(t *testing.T) {
	data := common.K8sManifest{}

	validator := HasDocumentsValidator{2}
	pass, diff := validator.Validate(&ValidateContext{
		Docs:     []common.K8sManifest{data, data},
		Negative: true,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Expected documents count NOT to be:	2",
	}, diff)
}
