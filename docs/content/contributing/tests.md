---
title: 'Contributing | Tests'
---

1. Install docker
2. Execute `git submodule update --init --recursive`
3. Install jq

    > MacOS Specific (needed for tests):
      ```bash
      brew install coreutils
      # bash >= 4.0 for associative arrays
      brew install bash
      ```

4. Execute `make`