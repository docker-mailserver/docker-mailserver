package validators_test

import (
	"github.com/lrills/helm-unittest/unittest/common"
	yaml "gopkg.in/yaml.v2"
)

func makeManifest(doc string) common.K8sManifest {
	manifest := common.K8sManifest{}
	yaml.Unmarshal([]byte(doc), &manifest)
	return manifest
}
