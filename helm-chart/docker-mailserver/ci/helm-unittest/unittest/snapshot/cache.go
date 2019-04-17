package snapshot

import (
	"io/ioutil"
	"os"

	"github.com/lrills/helm-unittest/unittest/common"
	yaml "gopkg.in/yaml.v2"
)

// CompareResult result return by Cache.Compare
type CompareResult struct {
	Passed         bool
	Test           string
	Index          uint
	NewSnapshot    string
	CachedSnapshot string
}

// Cache manage snapshot caching
type Cache struct {
	Filepath      string
	Existed       bool
	IsUpdating    bool
	cached        map[string]map[uint]string
	current       map[string]map[uint]string
	updatedCount  uint
	insertedCount uint
	currentCount  uint
}

// RestoreFromFile restore cached snapshot from cache file
func (s *Cache) RestoreFromFile() error {
	content, err := ioutil.ReadFile(s.Filepath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	if err := yaml.Unmarshal(content, &s.cached); err != nil {
		return err
	}
	s.Existed = true
	return nil
}

func (s *Cache) getCached(test string, idx uint) (string, bool) {
	if cachedByTest, ok := s.cached[test]; ok {
		if cachedOfAssertion, ok := cachedByTest[idx]; ok {
			return cachedOfAssertion, true
		}
	}
	return "", false
}

// Compare compare content to cached last time, return CompareResult
func (s *Cache) Compare(test string, idx uint, content interface{}) *CompareResult {
	s.currentCount++
	cached, exsisted := s.getCached(test, idx)
	if !exsisted {
		s.insertedCount++
	}

	match := true
	newSnapshot := common.TrustedMarshalYAML(content)
	if exsisted && newSnapshot != cached {
		match = false
		s.updatedCount++
	}

	var snapshotToSave string
	if s.IsUpdating || !exsisted {
		snapshotToSave = newSnapshot
	} else {
		snapshotToSave = cached
	}

	s.setNewSnapshot(test, idx, snapshotToSave)
	return &CompareResult{
		Passed:         s.IsUpdating || match,
		Test:           test,
		Index:          idx,
		CachedSnapshot: cached,
		NewSnapshot:    newSnapshot,
	}
}

func (s *Cache) setNewSnapshot(test string, idx uint, snapshot string) {
	if s.current == nil {
		s.current = make(map[string]map[uint]string)
	}
	if newCacheOfTest, ok := s.current[test]; ok {
		newCacheOfTest[idx] = snapshot
	} else {
		s.current[test] = map[uint]string{idx: snapshot}
	}
}

// Changed check if content have changed according to all Compare called
func (s *Cache) Changed() bool {
	if s.updatedCount > 0 || s.insertedCount > 0 {
		return true
	}

	for test, cachedFiles := range s.cached {
		if _, ok := s.current[test]; !ok {
			return true
		}
		for idx := range cachedFiles {
			if _, ok := s.current[test][idx]; !ok {
				return true
			}
		}
	}
	return false
}

// StoreToFileIfNeeded store current cache to file if snapshot content changed
func (s *Cache) StoreToFileIfNeeded() (bool, error) {
	if !s.Changed() {
		return false, nil
	}

	if s.IsUpdating || s.insertedCount > 0 || s.VanishedCount() > 0 {
		cacheData, err := yaml.Marshal(s.current)
		if err != nil {
			return false, err
		}

		if err := ioutil.WriteFile(s.Filepath, cacheData, 0644); err != nil {
			return false, err
		}

		s.Existed = true
		return true, nil
	}

	return false, nil
}

// UpdatedCount return snapshot count that was cached before and updated current time
func (s *Cache) UpdatedCount() uint {
	return s.updatedCount
}

// InsertedCount return snapshot count that was newly inserted current time
func (s *Cache) InsertedCount() uint {
	return s.insertedCount
}

// CurrentCount return total snapshot count of current time
func (s *Cache) CurrentCount() uint {
	return s.currentCount
}

// FailedCount return snapshot count that was failed when Compare
func (s *Cache) FailedCount() uint {
	if s.IsUpdating {
		return 0
	}
	return s.updatedCount
}

// VanishedCount return snapshot count that was cached last time but not exists this time
func (s *Cache) VanishedCount() uint {
	var count uint
	for test, cachedFiles := range s.cached {
		for idx := range cachedFiles {
			if newTestCache, ok := s.current[test]; ok {
				if _, ok := newTestCache[idx]; ok {
					continue
				}
			}
			count++
		}
	}
	return count
}
