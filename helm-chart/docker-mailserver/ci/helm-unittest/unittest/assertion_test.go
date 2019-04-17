package unittest_test

import (
	"testing"

	. "github.com/lrills/helm-unittest/unittest"
	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/snapshot"
	"github.com/stretchr/testify/assert"
	"gopkg.in/yaml.v2"
)

func TestAssertionUnmarshaledFromYAML(t *testing.T) {
	assertionsYAML := `
- equal:
- notEqual:
- matchRegex:
- notMatchRegex:
- contains:
- notContains:
- isNull:
- isNotNull:
- isEmpty:
- isNotEmpty:
- isKind:
- isAPIVersion:
- hasDocuments:
`
	assertionsAsMap := make([]map[string]interface{}, 13)
	yaml.Unmarshal([]byte(assertionsYAML), &assertionsAsMap)
	assertions := make([]Assertion, 13)
	yaml.Unmarshal([]byte(assertionsYAML), &assertions)

	a := assert.New(t)
	for idx, assertion := range assertions {
		_, ok := assertionsAsMap[idx][assertion.AssertType]
		a.True(ok)
		a.False(assertion.Not)
	}
}

func TestAssertionUnmarshaledFromYAMLWithNotTrue(t *testing.T) {
	assertionsYAML := `
- equal:
  not: true
- notEqual:
  not: true
- matchRegex:
  not: true
- notMatchRegex:
  not: true
- contains:
  not: true
- notContains:
  not: true
- isNull:
  not: true
- isNotNull:
  not: true
- isEmpty:
  not: true
- isNotEmpty:
  not: true
- isKind:
  not: true
- isAPIVersion:
  not: true
- hasDocuments:
  not: true
`
	assertions := make([]Assertion, 13)
	yaml.Unmarshal([]byte(assertionsYAML), &assertions)

	a := assert.New(t)
	for _, assertion := range assertions {
		a.True(assertion.Not)
	}
}

func TestReverseAssertionTheSameAsOriginalOneWithNotTrue(t *testing.T) {
	assertionsYAML := `
- equal:
	not: true
- notEqual:
- matchRegex:
	not: true
- notMatchRegex:
- contains:
	not: true
- notContains:
- isNull:
	not: true
- isNotNull:
- isEmpty:
	not: true
- isNotEmpty:
`
	assertions := make([]Assertion, 10)
	yaml.Unmarshal([]byte(assertionsYAML), &assertions)

	a := assert.New(t)
	for idx := 0; idx < len(assertions); idx += 2 {
		a.Equal(assertions[idx], assertions[idx+1])
	}
}

type fakeSnapshotComparer bool

func (c fakeSnapshotComparer) CompareToSnapshot(content interface{}) *snapshot.CompareResult {
	return &snapshot.CompareResult{
		Passed: bool(c),
	}
}

func TestAssertionAssertWhenOk(t *testing.T) {
	manifestDoc := `
kind: Fake
apiVersion: v123
a: b
c: [d]
`
	manifest := common.K8sManifest{}
	yaml.Unmarshal([]byte(manifestDoc), &manifest)
	renderedMap := map[string][]common.K8sManifest{
		"t.yaml": {manifest},
	}

	assertionsYAML := `
- template: t.yaml
  equal:
    path:  a
    value: b
- template: t.yaml
  notEqual:
    path:  a
    value: c
- template: t.yaml
  matchRegex:
    path:    a
    pattern: b
- template: t.yaml
  notMatchRegex:
    path:    a
    pattern: c
- template: t.yaml
  contains:
    path:    c
    content: d
- template: t.yaml
  notContains:
    path:    c
    content: e
- template: t.yaml
  isNull:
    path: x
- template: t.yaml
  isNotNull:
    path: a
- template: t.yaml
  isEmpty:
    path: z
- template: t.yaml
  isNotEmpty:
    path: c
- template: t.yaml
  isKind:
    of: Fake
- template: t.yaml
  isAPIVersion:
    of: v123
- template: t.yaml
  hasDocuments:
    count: 1
- template: t.yaml
  matchSnapshot: {}
`
	assertions := make([]Assertion, 13)
	err := yaml.Unmarshal([]byte(assertionsYAML), &assertions)

	a := assert.New(t)
	a.Nil(err)

	for idx, assertion := range assertions {
		result := assertion.Assert(renderedMap, fakeSnapshotComparer(true), &AssertionResult{Index: idx})
		a.Equal(&AssertionResult{
			Index:      idx,
			FailInfo:   []string{},
			Passed:     true,
			AssertType: assertion.AssertType,
			Not:        false,
			CustomInfo: "",
		}, result)
	}
}

func TestAssertionAssertWhenTemplateNotExisted(t *testing.T) {
	manifest := common.K8sManifest{}
	renderedMap := map[string][]common.K8sManifest{
		"existed.yaml": {manifest},
	}
	assertionYAML := `
template: not-existed.yaml
equal:
`
	assertion := new(Assertion)
	err := yaml.Unmarshal([]byte(assertionYAML), &assertion)

	a := assert.New(t)
	a.Nil(err)

	result := assertion.Assert(renderedMap, fakeSnapshotComparer(true), &AssertionResult{Index: 0})
	a.Equal(&AssertionResult{
		Index:      0,
		FailInfo:   []string{"Error:", "\ttemplate \"not-existed.yaml\" not exists or not selected in test suite"},
		Passed:     false,
		AssertType: "equal",
		Not:        false,
		CustomInfo: "",
	}, result)
}

func TestAssertionAssertWhenTemplateNotSpecifiedAndNoDefault(t *testing.T) {
	manifest := common.K8sManifest{}
	renderedMap := map[string][]common.K8sManifest{
		"existed.yaml": {manifest},
	}
	assertionYAML := "equal:"
	assertion := new(Assertion)
	yaml.Unmarshal([]byte(assertionYAML), &assertion)

	a := assert.New(t)
	result := assertion.Assert(renderedMap, fakeSnapshotComparer(true), &AssertionResult{Index: 0})
	a.Equal(&AssertionResult{
		Index:      0,
		FailInfo:   []string{"Error:", "\tassertion.template must be given if testsuite.templates is empty"},
		Passed:     false,
		AssertType: "equal",
		Not:        false,
		CustomInfo: "",
	}, result)
}
