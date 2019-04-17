package unittest

import (
	"fmt"
	"reflect"

	"github.com/lrills/helm-unittest/unittest/common"
	"github.com/lrills/helm-unittest/unittest/validators"

	"github.com/mitchellh/mapstructure"
)

// Assertion defines target and metrics to validate rendered result
type Assertion struct {
	Template      string
	DocumentIndex int
	Not           bool
	AssertType    string
	validator     validators.Validatable
	antonym       bool
}

// Assert validate the rendered manifests with validator
func (a *Assertion) Assert(
	templatesResult map[string][]common.K8sManifest,
	snapshotComparer validators.SnapshotComparer,
	result *AssertionResult,
) *AssertionResult {
	result.AssertType = a.AssertType
	result.Not = a.Not

	rendered, ok := templatesResult[a.Template]
	if !ok {
		result.FailInfo = []string{"Error:", a.noFileErrMessage()}
		return result
	}

	result.Passed, result.FailInfo = a.validator.Validate(&validators.ValidateContext{
		Docs:             rendered,
		Index:            a.DocumentIndex,
		Negative:         a.Not != a.antonym,
		SnapshotComparer: snapshotComparer,
	})
	return result
}

func (a *Assertion) noFileErrMessage() string {
	if a.Template != "" {
		return fmt.Sprintf(
			"\ttemplate \"%s\" not exists or not selected in test suite",
			a.Template,
		)
	}
	return "\tassertion.template must be given if testsuite.templates is empty"
}

// UnmarshalYAML implement yaml.Unmalshaler, construct validator according to the assert type
func (a *Assertion) UnmarshalYAML(unmarshal func(interface{}) error) error {
	assertDef := make(map[string]interface{})
	if err := unmarshal(&assertDef); err != nil {
		return err
	}

	if documentIndex, ok := assertDef["documentIndex"].(int); ok {
		a.DocumentIndex = documentIndex
	}
	if not, ok := assertDef["not"].(bool); ok {
		a.Not = not
	}
	if template, ok := assertDef["template"].(string); ok {
		a.Template = template
	}

	if err := a.constructValidator(assertDef); err != nil {
		return err
	}

	if a.validator == nil {
		for key := range assertDef {
			if key != "file" && key != "documentIndex" && key != "not" {
				return fmt.Errorf("Assertion type `%s` is invalid", key)
			}
		}
		return fmt.Errorf("No assertion type defined")
	}

	return nil
}

func (a *Assertion) constructValidator(assertDef map[string]interface{}) error {
	for assertName, correspondDef := range assertTypeMapping {
		if params, ok := assertDef[assertName]; ok {
			if a.validator != nil {
				return fmt.Errorf(
					"Assertion type `%s` and `%s` is declared duplicately",
					a.AssertType,
					assertName,
				)
			}

			validator := reflect.New(correspondDef.validatorType).Interface()
			if err := mapstructure.Decode(params, validator); err != nil {
				return err
			}

			a.AssertType = assertName
			a.validator = validator.(validators.Validatable)
			a.antonym = correspondDef.antonym
		}
	}
	return nil
}

type assertTypeDef struct {
	validatorType reflect.Type
	antonym       bool
}

var assertTypeMapping = map[string]assertTypeDef{
	"matchSnapshot": {reflect.TypeOf(validators.MatchSnapshotValidator{}), false},
	"equal":         {reflect.TypeOf(validators.EqualValidator{}), false},
	"notEqual":      {reflect.TypeOf(validators.EqualValidator{}), true},
	"matchRegex":    {reflect.TypeOf(validators.MatchRegexValidator{}), false},
	"notMatchRegex": {reflect.TypeOf(validators.MatchRegexValidator{}), true},
	"contains":      {reflect.TypeOf(validators.ContainsValidator{}), false},
	"notContains":   {reflect.TypeOf(validators.ContainsValidator{}), true},
	"isNull":        {reflect.TypeOf(validators.IsNullValidator{}), false},
	"isNotNull":     {reflect.TypeOf(validators.IsNullValidator{}), true},
	"isEmpty":       {reflect.TypeOf(validators.IsEmptyValidator{}), false},
	"isNotEmpty":    {reflect.TypeOf(validators.IsEmptyValidator{}), true},
	"isKind":        {reflect.TypeOf(validators.IsKindValidator{}), false},
	"isAPIVersion":  {reflect.TypeOf(validators.IsAPIVersionValidator{}), false},
	"hasDocuments":  {reflect.TypeOf(validators.HasDocumentsValidator{}), false},
}
