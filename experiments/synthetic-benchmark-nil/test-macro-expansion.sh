#!/bin/bash
# Direct Macro Expansion Comparison
#
# This script directly compares how macros expand with baseline vs optimized Clojure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/macro-expansion-test"
CLOJURE_VERSION="1.12.3"

CLOJURE_JAR_URL="https://repo1.maven.org/maven2/org/clojure/clojure/${CLOJURE_VERSION}/clojure-${CLOJURE_VERSION}.jar"
CLOJURE_JAR_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

SPEC_ALPHA_URL="https://repo1.maven.org/maven2/org/clojure/spec.alpha/0.5.238/spec.alpha-0.5.238.jar"
SPEC_ALPHA_SHA256="94cd99b6ea639641f37af4860a643b6ed399ee5a8be5d717cff0b663c8d75077"

CORE_SPECS_URL="https://repo1.maven.org/maven2/org/clojure/core.specs.alpha/0.4.74/core.specs.alpha-0.4.74.jar"
CORE_SPECS_SHA256="eb73ac08cf49ba840c88ba67beef11336ca554333d9408808d78946e0feb9ddb"

# Function to download with SHA256 check
download_verify() {
    local url="$1"
    local file="$2"
    local sha256="$3"
    
    if [ ! -f "$file" ]; then
        curl -sL -o "$file" "$url"
    fi
    
    local actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$sha256" ]; then
        echo "ERROR: SHA256 mismatch!"
        echo "Expected: $sha256"
        echo "Got:      $actual"
        exit 1
    fi
}

mkdir -p "$WORK_DIR/lib"

echo "============================================"
echo "Macro Expansion Comparison Test"
echo "============================================"
echo ""

# Download JARs
echo "Preparing Clojure JARs..."
download_verify "$CLOJURE_JAR_URL" "$WORK_DIR/lib/baseline.jar" "$CLOJURE_JAR_SHA256"
download_verify "$SPEC_ALPHA_URL" "$WORK_DIR/lib/spec.alpha.jar" "$SPEC_ALPHA_SHA256"
download_verify "$CORE_SPECS_URL" "$WORK_DIR/lib/core.specs.alpha.jar" "$CORE_SPECS_SHA256"
echo "  ✓ Baseline JARs ready (SHA256 verified)"

# Build optimized
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ ! -f "$WORK_DIR/lib/optimized.jar" ]; then
    cd "$REPO_ROOT"
    mvn -q -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | tail -3
    BUILT=$(find target -name "clojure-*.jar" -not -name "*-slim.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | head -1)
    cp "$BUILT" "$WORK_DIR/lib/optimized.jar"
fi
OPT_SHA=$(sha256sum "$WORK_DIR/lib/optimized.jar" | awk '{print $1}')
echo "  ✓ Optimized JAR ready (SHA256: ${OPT_SHA:0:16}...)"
echo ""

# Build classpaths
BASE_CP="$WORK_DIR/lib/baseline.jar:$WORK_DIR/lib/spec.alpha.jar:$WORK_DIR/lib/core.specs.alpha.jar"
OPT_CP="$WORK_DIR/lib/optimized.jar:$WORK_DIR/lib/spec.alpha.jar:$WORK_DIR/lib/core.specs.alpha.jar"

# Test macro expansions
echo "Test 1: Simple syntax-quoted nil"
echo "=========================================="
echo "Baseline expansion:"
java -cp "$BASE_CP" clojure.main -e "(defmacro test1 [] \`nil) (pr-str (macroexpand-1 '(test1)))" 2>/dev/null || echo "(failed)"

echo ""
echo "Optimized expansion:"
java -cp "$OPT_CP" clojure.main -e "(defmacro test1 [] \`nil) (pr-str (macroexpand-1 '(test1)))" 2>/dev/null || echo "(failed)"

echo ""
echo ""
echo "Test 2: Conditional with nil"
echo "=========================================="
echo "Baseline expansion:"
java -cp "$BASE_CP" clojure.main -e "(defmacro test2 [x] \`(if ~x nil :default)) (clojure.pprint/pprint (macroexpand-1 '(test2 foo)))" 2>/dev/null || echo "(failed)"

echo ""
echo "Optimized expansion:"
java -cp "$OPT_CP" clojure.main -e "(defmacro test2 [x] \`(if ~x nil :default)) (clojure.pprint/pprint (macroexpand-1 '(test2 foo)))" 2>/dev/null || echo "(failed)"

echo ""
echo ""
echo "Test 3: Vector of nils"
echo "=========================================="
echo "Baseline expansion:"
java -cp "$BASE_CP" clojure.main -e "(defmacro test3 [] \`[nil nil nil]) (clojure.pprint/pprint (macroexpand-1 '(test3)))" 2>/dev/null || echo "(failed)"

echo ""
echo "Optimized expansion:"
java -cp "$OPT_CP" clojure.main -e "(defmacro test3 [] \`[nil nil nil]) (clojure.pprint/pprint (macroexpand-1 '(test3)))" 2>/dev/null || echo "(failed)"

echo ""
echo ""
echo "Test 4: Map with nil values"
echo "=========================================="
echo "Baseline expansion:"
java -cp "$BASE_CP" clojure.main -e "(defmacro test4 [] \`{:a nil :b nil}) (clojure.pprint/pprint (macroexpand-1 '(test4)))" 2>/dev/null || echo "(failed)"

echo ""
echo "Optimized expansion:"
java -cp "$OPT_CP" clojure.main -e "(defmacro test4 [] \`{:a nil :b nil}) (clojure.pprint/pprint (macroexpand-1 '(test4)))" 2>/dev/null || echo "(failed)"

echo ""
echo ""
echo "============================================"
echo "Analysis"
echo "============================================"
echo ""
echo "Look for the key difference:"
echo "  BASELINE should show: (quote nil)"
echo "  OPTIMIZED should show: nil"
echo ""
echo "If you see this difference, the optimization is working!"
echo ""
echo "SHA256 Checksums (for reproducibility):"
echo "  Baseline:  $CLOJURE_JAR_SHA256"
echo "  Optimized: $OPT_SHA"
echo ""

exit 0
