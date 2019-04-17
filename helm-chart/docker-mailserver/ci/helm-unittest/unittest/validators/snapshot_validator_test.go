package validators_test

import (
	"testing"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/snapshot"
	. "github.com/lrills/helm-unittest/unittest/validators"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

type mockSnapshotComparer struct {
	mock.Mock
}

func (m *mockSnapshotComparer) CompareToSnapshot(content interface{}) *snapshot.CompareResult {
	args := m.Called(content)
	return args.Get(0).(*snapshot.CompareResult)
}

func TestSnapshotValidatorWhenOk(t *testing.T) {
	data := common.K8sManifest{"a": "b"}
	validator := MatchSnapshotValidator{Path: "a"}

	mockComparer := new(mockSnapshotComparer)
	mockComparer.On("CompareToSnapshot", "b").Return(&snapshot.CompareResult{
		Passed: true,
	})

	pass, diff := validator.Validate(&ValidateContext{
		Docs:             []common.K8sManifest{data},
		SnapshotComparer: mockComparer,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)

	mockComparer.AssertExpectations(t)
}

func TestSnapshotValidatorWhenNegativeAndOk(t *testing.T) {
	data := common.K8sManifest{"a": "b"}
	validator := MatchSnapshotValidator{Path: "a"}

	mockComparer := new(mockSnapshotComparer)
	mockComparer.On("CompareToSnapshot", "b").Return(&snapshot.CompareResult{
		Passed:         false,
		CachedSnapshot: "a:\n  b: c\n",
		NewSnapshot:    "x:\n  y: x\n",
	})

	pass, diff := validator.Validate(&ValidateContext{
		Negative:         true,
		Docs:             []common.K8sManifest{data},
		SnapshotComparer: mockComparer,
	})

	assert.True(t, pass)
	assert.Equal(t, []string{}, diff)

	mockComparer.AssertExpectations(t)
}

func TestSnapshotValidatorWhenFail(t *testing.T) {
	data := common.K8sManifest{"a": "b"}
	validator := MatchSnapshotValidator{Path: "a"}

	mockComparer := new(mockSnapshotComparer)
	mockComparer.On("CompareToSnapshot", "b").Return(&snapshot.CompareResult{
		Passed:         false,
		CachedSnapshot: "a:\n  b: c\n",
		NewSnapshot:    "x:\n  y: x\n",
	})

	pass, diff := validator.Validate(&ValidateContext{
		Docs:             []common.K8sManifest{data},
		SnapshotComparer: mockComparer,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a",
		"Expected to match snapshot 0:",
		"	--- Expected",
		"	+++ Actual",
		"	@@ -1,3 +1,3 @@",
		"	-a:",
		"	-  b: c",
		"	+x:",
		"	+  y: x",
	}, diff)

	mockComparer.AssertExpectations(t)
}

func TestSnapshotValidatorWhenNegativeAndFail(t *testing.T) {
	data := common.K8sManifest{"a": "b"}
	validator := MatchSnapshotValidator{Path: "a"}

	cached := "a:\n  b: c\n"
	mockComparer := new(mockSnapshotComparer)
	mockComparer.On("CompareToSnapshot", "b").Return(&snapshot.CompareResult{
		Passed:         true,
		CachedSnapshot: cached,
		NewSnapshot:    cached,
	})

	pass, diff := validator.Validate(&ValidateContext{
		Negative:         true,
		Docs:             []common.K8sManifest{data},
		SnapshotComparer: mockComparer,
	})

	assert.False(t, pass)
	assert.Equal(t, []string{
		"Path:	a",
		"Expected NOT to match snapshot 0:",
		"	a:",
		"	  b: c",
	}, diff)

	mockComparer.AssertExpectations(t)
}
