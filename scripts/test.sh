#!/bin/bash
#
# Runs the test suite.
#
# swift-testing ships inside the toolchain rather than the SDK, so when only the
# Command Line Tools are installed SwiftPM cannot find Testing.framework on its
# own and it has to be pointed at both the framework and its interop library.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVELOPER_DIR_PATH="$(xcode-select --print-path)"
FRAMEWORKS="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
INTEROP="$DEVELOPER_DIR_PATH/Library/Developer/usr/lib"

ARGS=()
if [[ -d "$FRAMEWORKS/Testing.framework" ]]; then
	ARGS+=(-Xswiftc -F -Xswiftc "$FRAMEWORKS")
	ARGS+=(-Xlinker -F -Xlinker "$FRAMEWORKS")
	ARGS+=(-Xlinker -rpath -Xlinker "$FRAMEWORKS")
	ARGS+=(-Xlinker -rpath -Xlinker "$INTEROP")
fi

# ${ARGS[@]+...} rather than a plain "${ARGS[@]}": macOS ships bash 3.2, where
# expanding an empty array under `set -u` is an unbound variable error. ARGS is
# empty whenever Testing.framework is not where the Command Line Tools put it,
# which is the case on a runner with full Xcode.
exec swift test ${ARGS[@]+"${ARGS[@]}"} "$@"
