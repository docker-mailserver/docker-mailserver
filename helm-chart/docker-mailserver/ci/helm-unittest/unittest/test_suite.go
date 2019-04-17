package unittest

import (
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/lrills/helm-unittest/unittest/snapshot"
	"gopkg.in/yaml.v2"
	"k8s.io/helm/pkg/proto/hapi/chart"
)

// ParseTestSuiteFile parse a suite file at path and returns TestSuite
func ParseTestSuiteFile(suiteFilePath, chartRoute string) (*TestSuite, error) {
	suite := TestSuite{chartRoute: chartRoute}
	content, err := ioutil.ReadFile(suiteFilePath)
	if err != nil {
		return &suite, err
	}

	cwd, _ := os.Getwd()
	absPath, _ := filepath.Abs(suiteFilePath)
	suite.definitionFile, err = filepath.Rel(cwd, absPath)
	if err != nil {
		return &suite, err
	}

	if err := yaml.Unmarshal(content, &suite); err != nil {
		return &suite, err
	}

	return &suite, nil
}

// TestSuite defines scope and templates to render and tests to run
type TestSuite struct {
	Name      string `yaml:"suite"`
	Templates []string
	Tests     []*TestJob
	// where the test suite file located
	definitionFile string
	// route indicate which chart in the dependency hierarchy
	// like "parant-chart", "parent-charts/charts/child-chart"
	chartRoute string
}

// Run runs all the test jobs defined in TestSuite
func (s *TestSuite) Run(
	targetChart *chart.Chart,
	snapshotCache *snapshot.Cache,
	result *TestSuiteResult,
) *TestSuiteResult {
	s.polishTestJobsPathInfo()

	result.DisplayName = s.Name
	result.FilePath = s.definitionFile

	preparedChart, err := s.prepareChart(targetChart)
	if err != nil {
		result.ExecError = err
		return result
	}

	result.Passed, result.TestsResult = s.runTestJobs(
		preparedChart,
		snapshotCache,
	)

	result.countSnapshot(snapshotCache)
	return result
}

// fill file path related info of TestJob
func (s *TestSuite) polishTestJobsPathInfo() {
	for _, test := range s.Tests {
		test.chartRoute = s.chartRoute
		test.definitionFile = s.definitionFile
		if len(s.Templates) > 0 {
			test.defaultTemplateToAssert = s.Templates[0]
		}
	}
}

func (s *TestSuite) prepareChart(targetChart *chart.Chart) (*chart.Chart, error) {
	copiedChart := new(chart.Chart)
	*copiedChart = *targetChart

	suiteIsFromRootChart := len(strings.Split(s.chartRoute, string(filepath.Separator))) <= 1

	if len(s.Templates) == 0 && suiteIsFromRootChart {
		return copiedChart, nil
	}

	filteredTemplate := make([]*chart.Template, 0, len(s.Templates))
	// check templates and add them in chart dependencies, if from subchart leave it empty
	if suiteIsFromRootChart {
		for _, fileName := range s.Templates {
			found := false
			for _, template := range targetChart.Templates {
				if filepath.Base(template.Name) == fileName {
					filteredTemplate = append(filteredTemplate, template)
					found = true
					break
				}
			}
			if !found {
				return &chart.Chart{}, fmt.Errorf(
					"template file `templates/%s` not found in chart",
					fileName,
				)
			}
		}
	}

	// add templates with extension .tpl
	for _, template := range targetChart.Templates {
		if path.Ext(template.Name) == ".tpl" {
			filteredTemplate = append(filteredTemplate, template)
		}
	}
	copiedChart.Templates = filteredTemplate

	return copiedChart, nil
}

func (s *TestSuite) runTestJobs(
	chart *chart.Chart,
	cache *snapshot.Cache,
) (bool, []*TestJobResult) {
	suitePass := true
	jobResults := make([]*TestJobResult, len(s.Tests))

	for idx, testJob := range s.Tests {
		jobResult := testJob.Run(chart, cache, &TestJobResult{Index: idx})
		jobResults[idx] = jobResult

		if !jobResult.Passed {
			suitePass = false
		}
	}
	return suitePass, jobResults
}
