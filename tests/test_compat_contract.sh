#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT/app/src/main/java/top/x67611/sidekeycirclesearch/ModuleMain.java"
SCOPE="$ROOT/app/src/main/resources/META-INF/xposed/scope.list"

require() {
    if ! grep -Fq "$1" "$2"; then
        echo "missing required contract: $1" >&2
        exit 1
    fi
}

reject() {
    if grep -Fq "$1" "$2"; then
        echo "forbidden contract found: $1" >&2
        exit 1
    fi
}

require 'com.google.android.googlequicksearchbox' "$SCOPE"
require 'system' "$SCOPE"
require 'SM-S928B' "$SOURCE"
require 'ro.opa.eligible_device' "$SOURCE"
require 'android.software.contextualsearch' "$SOURCE"
require 'com.google.android.feature.CONTEXTUAL_SEARCH' "$SOURCE"
require 'com.google.android.feature.GOOGLE_BUILD' "$SOURCE"
require 'com.google.android.feature.GOOGLE_EXPERIENCE' "$SOURCE"
require 'ContextualSearchManagerService' "$SOURCE"
require 'startOtherServices' "$SOURCE"
require 'getContextualSearchPackageName' "$SOURCE"

reject '781' "$SOURCE"
reject 'EVIOCGRAB' "$SOURCE"
reject 'VOICE_ASSIST' "$SOURCE"
reject 'google://lens' "$SOURCE"
reject 'enforcePermission' "$SOURCE"
reject 'PhoneWindowManager' "$SOURCE"
reject 'startContextualSearch' "$SOURCE"

test "$(wc -l < "$SCOPE" | tr -d ' ')" = 2
echo "Contextual service route + Google eligibility contract: PASS"
