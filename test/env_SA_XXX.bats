####################################################################################################
#
# SA_XXX with default configuraton
#
####################################################################################################

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ -n "$SA_TAG" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  [ "$status" -eq 0 ]
}

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ -n "$SA_TAG2" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  [ "$status" -eq 0 ]
}

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ -n "$SA_KILL" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 6.31'"
  [ "$status" -eq 0 ]
}

####################################################################################################
#
# SA_XXX with custom configuraton
#
####################################################################################################

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ -z "$SA_TAG" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= $SA_TAG'"
  [ "$status" -eq 0 ]
}

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ -z "$SA_TAG" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= $SA_TAG2'"
  [ "$status" -eq 0 ]
}

@test "checking spamassassin: docker env variables are set correctly (default)" {
  if [ -z "$SA_TAG" ]; then
    skip
  fi
  run docker exec mail /bin/sh -c "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= $SA_KILL'"
  [ "$status" -eq 0 ]
}
