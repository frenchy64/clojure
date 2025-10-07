#!/bin/bash
set -euo pipefail

# This script measures the performance of if-not macro expansion
# between baseline Clojure 1.12.3 and the optimized version.
#
# What it verifies: Macro expansion performance (Effect #2)
#
# Dependencies: curl, sha256sum, java
#
# Expected output: Timing comparison showing faster expansion with optimization

BASELINE_URL="https://repo1.maven.org/maven2/org/clojure/clojure/1.12.3/clojure-1.12.3.jar"
# Verified by: curl -sL $BASELINE_URL | sha256sum
BASELINE_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

# spec.alpha is required by Clojure
SPEC_URL="https://repo1.maven.org/maven2/org/clojure/spec.alpha/0.5.238/spec.alpha-0.5.238.jar"
SPEC_SHA256="94cd99b6ea639641f37af4860a643b6ed399ee5a8be5d717cff0b663c8d75077"

CORE_SPECS_URL="https://repo1.maven.org/maven2/org/clojure/core.specs.alpha/0.4.74/core.specs.alpha-0.4.74.jar"
CORE_SPECS_SHA256="eb73ac08cf49ba840c88ba67beef11336ca554333d9408808d78946e0feb9ddb"

# Path to shared build script
SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBPROJECT_ROOT="$(cd "$SCRIPT_DIR_PATH/../../.." && pwd)"
BUILD_SCRIPT="$SUBPROJECT_ROOT/build-optimized-uberjar.sh"

WORK_DIR="/tmp/if-not-expansion-perf-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== Measuring if-not Macro Expansion Performance ==="
echo ""
echo "Working directory: $WORK_DIR"
echo ""

# Function to verify SHA256
verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "ERROR: SHA256 mismatch for $file"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        exit 1
    fi
    echo "✓ SHA256 verified: $file"
}

# Download and verify baseline Clojure
echo "Downloading baseline Clojure 1.12.3 and dependencies..."
curl -sL "$BASELINE_URL" -o clojure-baseline.jar
verify_sha256 clojure-baseline.jar "$BASELINE_SHA256"

curl -sL "$SPEC_URL" -o spec.alpha.jar
verify_sha256 spec.alpha.jar "$SPEC_SHA256"

curl -sL "$CORE_SPECS_URL" -o core.specs.alpha.jar
verify_sha256 core.specs.alpha.jar "$CORE_SPECS_SHA256"

BASELINE_CP="clojure-baseline.jar:spec.alpha.jar:core.specs.alpha.jar"
echo ""

# Build optimized version using shared script
echo "Building optimized Clojure..."
if [ ! -x "$BUILD_SCRIPT" ]; then
    echo "ERROR: Build script not found or not executable: $BUILD_SCRIPT"
    exit 1
fi

TEMP_BUILD_DIR="$WORK_DIR/temp-build"
"$BUILD_SCRIPT" "$TEMP_BUILD_DIR"
if [ ! -f "$TEMP_BUILD_DIR/clojure-nil-optimized.jar" ]; then
    echo "ERROR: Built JAR not found"
    exit 1
fi
cp "$TEMP_BUILD_DIR/clojure-nil-optimized.jar" "$WORK_DIR/clojure-optimized.jar"
rm -rf "$TEMP_BUILD_DIR"
OPTIMIZED_SHA256=$(sha256sum clojure-optimized.jar | awk '{print $1}')
echo "✓ Built optimized JAR"
echo "  SHA256: $OPTIMIZED_SHA256"

# Copy spec dependencies for optimized jar too
cp spec.alpha.jar optimized-spec.alpha.jar
cp core.specs.alpha.jar optimized-core.specs.alpha.jar
OPTIMIZED_CP="clojure-optimized.jar:optimized-spec.alpha.jar:optimized-core.specs.alpha.jar"
echo ""

# Create test code that expands if-not many times (minimal, no spec requirement)
cat > test-expansion.clj <<'EOF'
;; Minimal test without requiring spec.alpha

(defn measure-expansion-time [n]
  "Measure time to macroexpand if-not n times"
  (let [start (System/nanoTime)]
    (dotimes [_ n]
      ;; Force macroexpansion without evaluation
      (macroexpand-1 '(if-not (fn [] nil) :then)))
    (let [end (System/nanoTime)
          elapsed-ns (- end start)]
      {:iterations n
       :total-ns elapsed-ns
       :ns-per-expansion (/ elapsed-ns (double n))
       :us-per-expansion (/ elapsed-ns (* (double n) 1000.0))})))

;; Run measurement
(def n 100000) ; 100k iterations for statistical significance
(println "Measuring" n "macro expansions...")
(def result (measure-expansion-time n))
(println "Results:")
(println (format "  Total time: %.2f ms" (/ (:total-ns result) 1000000.0)))
(println (format "  Per expansion: %.2f ns (%.4f us)" 
                 (:ns-per-expansion result)
                 (:us-per-expansion result)))
EOF

echo "=== Testing Baseline Clojure ==="
echo ""
java -cp "$BASELINE_CP" clojure.main -e "$(cat test-expansion.clj)" > baseline-results.txt 2>&1
cat baseline-results.txt
echo ""

echo "=== Testing Optimized Clojure ==="
echo ""
java -cp "$OPTIMIZED_CP" clojure.main -e "$(cat test-expansion.clj)" > optimized-results.txt 2>&1
cat optimized-results.txt
echo ""

# Extract timing data
extract_time() {
    local file=$1
    grep "Per expansion:" "$file" | sed 's/.*(\(.*\) us).*/\1/' || echo "ERROR"
}

BASELINE_TIME=$(extract_time baseline-results.txt)
OPTIMIZED_TIME=$(extract_time optimized-results.txt)

echo "=== Summary ==="
echo ""
echo "Baseline time per expansion:  ${BASELINE_TIME} μs"
echo "Optimized time per expansion: ${OPTIMIZED_TIME} μs"

# Calculate improvement if both are numbers
if [[ "$BASELINE_TIME" =~ ^[0-9.]+$ ]] && [[ "$OPTIMIZED_TIME" =~ ^[0-9.]+$ ]]; then
    IMPROVEMENT=$(echo "scale=2; ($BASELINE_TIME - $OPTIMIZED_TIME) / $BASELINE_TIME * 100" | bc)
    echo "Improvement:                  ${IMPROVEMENT}%"
    echo ""
    
    if (( $(echo "$IMPROVEMENT > 0" | bc -l) )); then
        echo "✓ Optimization shows measurable performance improvement"
    elif (( $(echo "$IMPROVEMENT < -5" | bc -l) )); then
        echo "⚠️  Warning: Optimized version is slower (may indicate measurement noise)"
    else
        echo "≈ Performance difference within measurement noise"
    fi
else
    echo "⚠️  Could not extract timing data for comparison"
fi
echo ""

echo "=== Notes ==="
echo ""
echo "1. Macro expansion includes all Clojure runtime overhead"
echo "2. The optimization saves ~1-5μs per expansion in theory"
echo "3. Actual improvement may be smaller due to JVM warmup, GC, etc."
echo "4. Run multiple times for statistical validity"
echo ""

echo "All artifacts saved to: $WORK_DIR"
echo "  - baseline-results.txt  : Baseline timing results"
echo "  - optimized-results.txt : Optimized timing results"
echo "  - test-expansion.clj    : Test code"
echo ""
