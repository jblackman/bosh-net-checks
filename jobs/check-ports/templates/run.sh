#!/usr/bin/env bash

set -euo pipefail

BASE=$(dirname $0)/..
: ${CONFIG_FILE:=$BASE/config/port-checks.cfg}
[ -f "${CONFIG_FILE}" ] || { echo "Missing config file: ${CONFIG_FILE}"; exit 1; }

# temp files are a quick and dirty way to get variables out of a "while" subshell
TEST_COUNT=0
TESTS=/tmp/$$.tests; touch ${TESTS}
FAILS=/tmp/$$.fails; touch ${FAILS}
trap 'rm -f $TESTS $FAILS' EXIT

cat "${CONFIG_FILE}" | sed '/^\s*#/d' | while IFS=$'\t' read HOST PORT PROTOCOL SHOULD_FAIL DESCRIPTION; do
  TEST_COUNT=$((TEST_COUNT+1))
  echo "--------------------------------------------------"
  echo "Test ${TEST_COUNT}: ${DESCRIPTION}"
  echo "   Host/Port: ${HOST}/${PORT} (${PROTOCOL})"
  echo
  PROTOCOL_FLAG=
  [ "${PROTOCOL}" = udp ] && PROTOCOL_FLAG=-u

  [ "$SHOULD_FAIL" = true ] && echo ">>> We expect this test to fail: <<<"

  if  nc -zv -w 1 ${PROTOCOL_FLAG} "${HOST}" "${PORT}" 2>&1; then
    # success, but should it have failed?
    [ "$SHOULD_FAIL" = true ] && echo 1 >> $FAILS
  else
    # failure, but were we expecting it?
    [ "$SHOULD_FAIL" = true ] || echo 1 >> $FAILS
  fi
  echo
  echo 1 >> $TESTS
done

TEST_COUNT=$(wc -l <$TESTS)
FAILURE_COUNT=$(wc -l <$FAILS)
echo
echo "Number of failed tests: ${FAILURE_COUNT}/${TEST_COUNT}"
if [ "${FAILURE_COUNT}" -ne 0 ]; then
  echo "Not all tests were successful!"
  exit 1
fi
echo "All tests were successful"
