package snapshot_test

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	. "github.com/lrills/helm-unittest/unittest/snapshot"
	"github.com/stretchr/testify/assert"
)

var lastTimeContent = `cached before:
  1: |
    a:
      b: c
  2: |
    d:
      e: f
`

var snapshot1 = "a:\n  b: c\n"
var content1 = map[string]interface{}{
	"a": map[string]string{
		"b": "c",
	},
}

var snapshot2 = "d:\n  e: f\n"
var content2 = map[string]interface{}{
	"d": map[string]string{
		"e": "f",
	},
}

var snapshotNew = "x:\n  \"y\": z\n"
var contentNew = map[string]interface{}{
	"x": map[string]string{
		"y": "z",
	},
}

func createCache(existed bool) *Cache {
	dir, _ := ioutil.TempDir("", "test")
	cacheFile := filepath.Join(dir, "cache_test.yaml")
	if existed {
		ioutil.WriteFile(cacheFile, []byte(lastTimeContent), os.ModePerm)
	}

	return &Cache{Filepath: cacheFile}
}

func TestCacheWhenFirstTime(t *testing.T) {
	cache := createCache(false)
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.False(cache.Existed)
	a.False(cache.Changed())

	cache.Compare("new test", 1, content1)
	a.True(cache.Changed())
	a.False(cache.Existed)
	a.Equal(uint(1), cache.InsertedCount())
	a.Equal(uint(0), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.True(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	expectedCacheContent := `new test:
  1: |
    a:
      b: c
`
	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(expectedCacheContent, string(bytes))
}

func TestCacheWhenNotChanged(t *testing.T) {
	cache := createCache(true)
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	result := cache.Compare("cached before", 1, content1)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          1,
		Passed:         true,
		CachedSnapshot: snapshot1,
		NewSnapshot:    snapshot1,
	}, result)
	a.True(cache.Changed())

	result2 := cache.Compare("cached before", 2, content2)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          2,
		Passed:         true,
		CachedSnapshot: snapshot2,
		NewSnapshot:    snapshot2,
	}, result2)
	a.False(cache.Changed())

	a.Equal(uint(0), cache.InsertedCount())
	a.Equal(uint(0), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.False(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(lastTimeContent, string(bytes))
}

func TestCacheWhenChanged(t *testing.T) {
	cache := createCache(true)
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	cache.Compare("cached before", 1, content1)
	a.True(cache.Changed())

	result2 := cache.Compare("cached before", 2, contentNew)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          2,
		Passed:         false,
		CachedSnapshot: snapshot2,
		NewSnapshot:    snapshotNew,
	}, result2)
	a.True(cache.Changed())

	a.Equal(uint(0), cache.InsertedCount())
	a.Equal(uint(1), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.False(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(lastTimeContent, string(bytes))
}

func TestCacheWhenNotChangedIfIsUpdating(t *testing.T) {
	cache := createCache(true)
	cache.IsUpdating = true
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	result := cache.Compare("cached before", 1, content1)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          1,
		Passed:         true,
		CachedSnapshot: snapshot1,
		NewSnapshot:    snapshot1,
	}, result)
	a.True(cache.Changed())

	result2 := cache.Compare("cached before", 2, content2)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          2,
		Passed:         true,
		CachedSnapshot: snapshot2,
		NewSnapshot:    snapshot2,
	}, result2)
	a.False(cache.Changed())

	a.Equal(uint(0), cache.InsertedCount())
	a.Equal(uint(0), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.False(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(lastTimeContent, string(bytes))
}

func TestCacheWhenChangedIfIsUpdating(t *testing.T) {
	cache := createCache(true)
	cache.IsUpdating = true
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	cache.Compare("cached before", 1, content1)
	a.True(cache.Changed())

	result2 := cache.Compare("cached before", 2, contentNew)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          2,
		Passed:         true,
		CachedSnapshot: snapshot2,
		NewSnapshot:    snapshotNew,
	}, result2)
	a.True(cache.Changed())

	a.Equal(uint(0), cache.InsertedCount())
	a.Equal(uint(1), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.True(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(`cached before:
  1: |
    a:
      b: c
  2: |
    x:
      "y": z
`, string(bytes))
}

func TestCacheWhenHasVanished(t *testing.T) {
	cache := createCache(true)
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	cache.Compare("cached before", 1, content1)
	a.True(cache.Changed())

	a.Equal(uint(0), cache.InsertedCount())
	a.Equal(uint(0), cache.UpdatedCount())
	a.Equal(uint(1), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.True(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(`cached before:
  1: |
    a:
      b: c
`, string(bytes))
}

func TestCacheWhenHasInserted(t *testing.T) {
	cache := createCache(true)
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	cache.Compare("cached before", 1, content1)
	a.True(cache.Changed())

	cache.Compare("cached before", 2, content2)
	a.False(cache.Changed())

	result3 := cache.Compare("cached before", 3, contentNew)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          3,
		Passed:         true,
		CachedSnapshot: "",
		NewSnapshot:    snapshotNew,
	}, result3)
	a.True(cache.Changed())

	a.Equal(uint(1), cache.InsertedCount())
	a.Equal(uint(0), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.True(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(`cached before:
  1: |
    a:
      b: c
  2: |
    d:
      e: f
  3: |
    x:
      "y": z
`, string(bytes))
}

func TestCacheWhenNewOneAtMiddle(t *testing.T) {
	cache := createCache(true)
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	cache.Compare("cached before", 1, content1)
	a.True(cache.Changed())

	result2 := cache.Compare("cached before", 2, contentNew)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          2,
		Passed:         false,
		CachedSnapshot: snapshot2,
		NewSnapshot:    snapshotNew,
	}, result2)
	a.True(cache.Changed())

	result3 := cache.Compare("cached before", 3, content2)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          3,
		Passed:         true,
		CachedSnapshot: "",
		NewSnapshot:    snapshot2,
	}, result3)
	a.True(cache.Changed())

	a.Equal(uint(1), cache.InsertedCount())
	a.Equal(uint(1), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.True(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(`cached before:
  1: |
    a:
      b: c
  2: |
    d:
      e: f
  3: |
    d:
      e: f
`, string(bytes))
}

func TestCacheWhenNewOneAtMiddleIfIsUpdating(t *testing.T) {
	cache := createCache(true)
	cache.IsUpdating = true
	err := cache.RestoreFromFile()

	a := assert.New(t)
	a.Nil(err)
	a.True(cache.Existed)
	a.True(cache.Changed())

	cache.Compare("cached before", 1, content1)
	a.True(cache.Changed())

	result2 := cache.Compare("cached before", 2, contentNew)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          2,
		Passed:         true,
		CachedSnapshot: snapshot2,
		NewSnapshot:    snapshotNew,
	}, result2)
	a.True(cache.Changed())

	result3 := cache.Compare("cached before", 3, content2)
	a.Equal(&CompareResult{
		Test:           "cached before",
		Index:          3,
		Passed:         true,
		CachedSnapshot: "",
		NewSnapshot:    snapshot2,
	}, result3)
	a.True(cache.Changed())

	a.Equal(uint(1), cache.InsertedCount())
	a.Equal(uint(1), cache.UpdatedCount())
	a.Equal(uint(0), cache.VanishedCount())

	stored, storeErr := cache.StoreToFileIfNeeded()
	a.True(stored)
	a.Nil(storeErr)
	a.True(cache.Existed)

	bytes, _ := ioutil.ReadFile(cache.Filepath)
	a.Equal(`cached before:
  1: |
    a:
      b: c
  2: |
    x:
      "y": z
  3: |
    d:
      e: f
`, string(bytes))
}
