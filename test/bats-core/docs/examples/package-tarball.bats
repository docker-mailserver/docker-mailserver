#!/usr/bin/env bats

setup() {
  export dst_tarball="${BATS_TMPDIR}/dst.tar.gz"
  export src_dir="${BATS_TMPDIR}/src_dir"

  rm -rf "${dst_tarball}" "${src_dir}"
  mkdir "${src_dir}"
  touch "${src_dir}"/{a,b,c}
}

main() {
  bash "${BATS_TEST_DIRNAME}"/package-tarball
}

@test 'fail when \$src_dir and \$dst_tarball are unbound' {
  unset src_dir dst_tarball

  run main
  [ "${status}" -ne 0 ]
}

@test 'fail when \$src_dir is a non-existent directory' {
  src_dir='not-a-dir'

  run main
  [ "${status}" -ne 0 ]
}

@test 'pass when \$src_dir directory is empty' {
  rm -rf "${src_dir:?}/*"

  run main
  echo "$output"
  [ "${status}" -eq 0 ]
}

@test 'files in \$src_dir are added to tar archive' {
  run main
  [ "${status}" -eq 0 ]

  run tar tf "$dst_tarball"
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ a ]]
  [[ "${output}" =~ b ]]
  [[ "${output}" =~ c ]]
}
