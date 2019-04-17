package unittest

import (
	"path/filepath"
	"strings"
)

func spliteChartRoutes(routePath string) []string {
	splited := strings.Split(routePath, string(filepath.Separator))
	routes := make([]string, len(splited)/2+1)
	for r := 0; r < len(routes); r++ {
		routes[r] = splited[r*2]
	}
	return routes
}

func scopeValuesWithRoutes(routes []string, values map[interface{}]interface{}) map[interface{}]interface{} {
	if len(routes) > 1 {
		return scopeValuesWithRoutes(
			routes[:len(routes)-1],
			map[interface{}]interface{}{
				routes[len(routes)-1]: values,
			},
		)
	}
	return values
}
