package common

import yaml "gopkg.in/yaml.v2"

// TrustedMarshalYAML marshal yaml without error returned, if an error happens it panics
func TrustedMarshalYAML(d interface{}) string {
	s, err := yaml.Marshal(d)
	if err != nil {
		panic(err)
	}
	return string(s)
}
