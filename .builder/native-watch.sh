#!/usr/bin/env bash
# Rebuild pushed native changes on this already-running CI simulator.
set -uo pipefail
SIM_ID="$1"
APP_PATH="$2"
LAST_REMOTE="${GITHUB_SHA:-$(git rev-parse HEAD)}"
BUILD_LOG="${RUNNER_TEMP:-/tmp}/prism-live-build.log"
printf 'native-watch: watching main on simulator %s\n' "$SIM_ID"
while sleep 5; do
  if ! git fetch --quiet origin main; then
    echo 'native-watch: fetch failed; will retry'
    continue
  fi
  NEXT_SHA=$(git rev-parse FETCH_HEAD)
  [ "$NEXT_SHA" != "$LAST_REMOTE" ] || continue
  LAST_REMOTE="$NEXT_SHA"
  CHANGED=$(git diff --name-only HEAD "$NEXT_SHA")
  if ! git checkout --quiet --detach "$NEXT_SHA"; then
    echo 'native-watch: checkout failed; keeping the installed build'
    continue
  fi
  if ! printf '%s\n' "$CHANGED" | grep -Eq '^Prism/|^Prism\.xcodeproj/'; then
    continue
  fi
  printf 'native-watch: compiling %s\n' "${NEXT_SHA:0:7}"
  if ! xcodebuild -project Prism.xcodeproj -scheme Prism -configuration Debug \
      -destination "id=$SIM_ID" -derivedDataPath "$GITHUB_WORKSPACE/DerivedData" \
      COMPILER_INDEX_STORE_ENABLE=NO CODE_SIGNING_ALLOWED=NO build >"$BUILD_LOG" 2>&1; then
    echo 'native-watch: build failed; previous app remains installed'
    tail -80 "$BUILD_LOG"
    continue
  fi
  xcrun simctl terminate "$SIM_ID" com.codystechcorner.prism.ios >/dev/null 2>&1 || true
  if xcrun simctl install "$SIM_ID" "$APP_PATH" && \
     xcrun simctl launch "$SIM_ID" com.codystechcorner.prism.ios; then
    printf 'native-watch: installed and launched %s\n' "${NEXT_SHA:0:7}"
  else
    echo 'native-watch: install/launch failed; inspect runner output'
  fi
done
