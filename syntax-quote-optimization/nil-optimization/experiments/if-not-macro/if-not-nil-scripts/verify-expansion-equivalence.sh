#!/bin/bash
set -euo pipefail

# This script verifies that if-not macro expansions are semantically equivalent
# between baseline Clojure 1.12.3 and the optimized version.

BASELINE_URL="https://repo1.maven.org/maven2/org/clojure/clojure/1.12.3/clojure-1.12.3.jar"
BASELINE_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

SPEC_URL="https://repo1.maven.org/maven2/org/clojure/spec.alpha/0.5.238/spec.alpha-0.5.238.jar"
SPEC_SHA256="94cd99b6ea639641f37af4860a643b6ed399ee5a8be5d717cff0b663c8d75077"

CORE_SPECS_URL="https://repo1.maven.org/maven2/org/clojure/core.specs.alpha/0.4.74/core.specs.alpha-0.4.74.jar"
CORE_SPECS_SHA256="eb73ac08cf49ba840c88ba67beef11336ca554333d9408808d78946e0feb9ddb"

# Path to shared build script
SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBPROJECT_ROOT="$(cd "$SCRIPT_DIR_PATH/../../.." && pwd)"
BUILD_SCRIPT="$SUBPROJECT_ROOT/build-optimized-uberjar.sh"

WORK_DIR="/tmp/if-not-expansion-equiv-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== Verifying if-not Macro Expansion Equivalence ==="
echo ""

verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "ERROR: SHA256 mismatch for $file"
        exit 1
    fi
    echo "✓ SHA256 verified: $file"
}

echo "Downloading baseline Clojure 1.12.3 and dependencies..."
curl -sL "$BASELINE_URL" -o clojure-baseline.jar
verify_sha256 clojure-baseline.jar "$BASELINE_SHA256"

curl -sL "$SPEC_URL" -o spec.alpha.jar
verify_sha256 spec.alpha.jar "$SPEC_SHA256"

curl -sL "$CORE_SPECS_URL" -o core.specs.alpha.jar
verify_sha256 core.specs.alpha.jar "$CORE_SPECS_SHA256"

BASELINE_CP="clojure-baseline.jar:spec.alpha.jar:core.specs.alpha.jar"
echo ""

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
echo "✓ Built optimized JAR"

cp spec.alpha.jar optimized-spec.alpha.jar
cp core.specs.alpha.jar optimized-core.specs.alpha.jar
OPTIMIZED_CP="clojure-optimized.jar:optimized-spec.alpha.jar:optimized-core.specs.alpha.jar"
echo ""

cat > test-equivalence.clj <<'EOF'
(println "Testing if-not expansion equivalence...")
(println "")

(println "Test 1: Basic 2-arity if-not")
(let [result1 (if-not nil :then)
      result2 (if-not false :then)
      result3 (if-not true :then)]
  (println "  (if-not nil :then)   =>" result1 (if (= result1 :then) "✓" "✗"))
  (println "  (if-not false :then) =>" result2 (if (= result2 :then) "✓" "✗"))
  (println "  (if-not true :then)  =>" result3 (if (nil? result3) "✓" "✗")))
(println "")

(println "Test 2: Runtime behavior equivalence")
(let [test-cases [
        [(fn [] (if-not nil :yes :no)) :yes "nil test"]
        [(fn [] (if-not false :yes :no)) :yes "false test"]
        [(fn [] (if-not true :yes :no)) :no "true test"]
        [(fn [] (if-not 0 :yes :no)) :no "0 test"]
        [(fn [] (if-not "" :yes :no)) :no "empty string test"]
        [(fn [] (if-not [] :yes :no)) :no "empty vector test"]
        [(fn [] (if-not (empty? [1]) :yes :no)) :yes "non-empty vector test"]
      ]]
  (doseq [[test-fn expected desc] test-cases]
    (let [actual (test-fn)
          status (if (= actual expected) "✓" "✗")]
      (println (format "  %-25s => %-10s (expected %-10s) %s" 
                       desc actual expected status)))))
(println "")

(println "Test 3: 2-arity if-not returns correct values")
(let [r1 (if-not true :unreachable)
      r2 (if-not false :reachable)]
  (println "  (if-not true :unreachable)  =>" r1 (if (nil? r1) "✓" "✗"))
  (println "  (if-not false :reachable)   =>" r2 (if (= r2 :reachable) "✓" "✗")))
(println "")

(println "=== All Tests Complete ===")
EOF

echo "=== Testing Baseline Clojure ==="
java -cp "$BASELINE_CP" clojure.main -e "$(cat test-equivalence.clj)" > baseline-equiv.txt 2>&1
cat baseline-equiv.txt
echo ""

echo "=== Testing Optimized Clojure ==="
java -cp "$OPTIMIZED_CP" clojure.main -e "$(cat test-equivalence.clj)" > optimized-equiv.txt 2>&1
cat optimized-equiv.txt
echo ""

echo "=== Comparing Results ==="
if diff -u baseline-equiv.txt optimized-equiv.txt > equivalence.diff; then
    echo "✓✓✓ IDENTICAL OUTPUT ✓✓✓"
else
    echo "⚠️  OUTPUTS DIFFER ⚠️"
    head -50 equivalence.diff
fi
echo ""

echo "All artifacts saved to: $WORK_DIR"
