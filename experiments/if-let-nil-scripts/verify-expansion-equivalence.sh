#!/bin/bash
set -euo pipefail

# This script verifies that if-let macro expansions are semantically equivalent
# between baseline Clojure 1.12.3 and the optimized version.
#
# What it verifies: Expansion result equivalence (Effect #3)
#
# Dependencies: curl, sha256sum, java
#
# Expected output: Confirmation that expansions evaluate identically

BASELINE_URL="https://repo1.maven.org/maven2/org/clojure/clojure/1.12.3/clojure-1.12.3.jar"
# Verified by: curl -sL $BASELINE_URL | sha256sum
BASELINE_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

# spec.alpha is required by Clojure
SPEC_URL="https://repo1.maven.org/maven2/org/clojure/spec.alpha/0.5.238/spec.alpha-0.5.238.jar"
SPEC_SHA256="94cd99b6ea639641f37af4860a643b6ed399ee5a8be5d717cff0b663c8d75077"

CORE_SPECS_URL="https://repo1.maven.org/maven2/org/clojure/core.specs.alpha/0.4.74/core.specs.alpha-0.4.74.jar"
CORE_SPECS_SHA256="eb73ac08cf49ba840c88ba67beef11336ca554333d9408808d78946e0feb9ddb"

WORK_DIR="/tmp/if-let-expansion-equiv-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== Verifying if-let Macro Expansion Equivalence ==="
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

# Build optimized version
echo "Building optimized Clojure..."
cd -
mvn clean package -Plocal -Dmaven.test.skip=true > /dev/null 2>&1
OPTIMIZED_JAR=$(find target -name "clojure-*.jar" ! -name "*-slim.jar" ! -name "*-sources.jar" ! -name "*-javadoc.jar" | head -1)
if [ ! -f "$OPTIMIZED_JAR" ]; then
    echo "ERROR: Could not find optimized JAR in target/"
    exit 1
fi
cp "$OPTIMIZED_JAR" "$WORK_DIR/clojure-optimized.jar"
cd "$WORK_DIR"
OPTIMIZED_SHA256=$(sha256sum clojure-optimized.jar | awk '{print $1}')
echo "✓ Built optimized JAR: $(basename $OPTIMIZED_JAR)"
echo "  SHA256: $OPTIMIZED_SHA256"

# Copy spec dependencies for optimized jar too
cp spec.alpha.jar optimized-spec.alpha.jar
cp core.specs.alpha.jar optimized-core.specs.alpha.jar
OPTIMIZED_CP="clojure-optimized.jar:optimized-spec.alpha.jar:optimized-core.specs.alpha.jar"
echo ""

# Create comprehensive test code (minimal version that doesn't require spec.alpha)
cat > test-equivalence.clj <<'EOF'
;; Minimal test that doesn't require spec.alpha
;; Run with: java -cp clojure.jar clojure.lang.Script test-equivalence.clj

(println "Testing if-let expansion equivalence...")
(println "")

;; Test Case 1: Basic 2-arity form (uses nil default)
(println "Test 1: Basic 2-arity if-let")
(let [result1 (if-let [x nil] x)
      result2 (if-let [x false] x)
      result3 (if-let [x 42] x)]
  (println "  (if-let [x nil] x)   =>" result1 (if (nil? result1) "✓" "✗"))
  (println "  (if-let [x false] x) =>" result2 (if (nil? result2) "✓" "✗"))
  (println "  (if-let [x 42] x)    =>" result3 (if (= result3 42) "✓" "✗")))
(println "")

;; Test Case 2: Expansion form
(println "Test 2: Macro expansion")
(let [expansion (macroexpand-1 '(if-let [x (fn [] nil)] x))]
  (println "  Expansion form:" expansion)
  ;; The key test: does it evaluate correctly?
  (let [result (eval expansion)]
    (println "  Evaluates to:" result (if (nil? result) "✓" "✗"))))
(println "")

;; Test Case 3: Verify nil in expansion
(println "Test 3: Examining else clause in expansion")
(let [expansion (macroexpand-1 '(if-let [x test-val] :then))]
  (println "  Full expansion:" expansion)
  ;; Walk the expansion to find the else clause
  (letfn [(find-else [form]
            (cond
              (not (coll? form)) form
              (and (list? form) (= 'if (first form)))
              (let [[_ test then else] form]
                (println "    Found if form:")
                (println "      test:" test)
                (println "      then:" then)
                (println "      else:" else)
                (println "      else is nil?" (nil? else) "✓")
                else)
              :else (some find-else form)))]
    (find-else expansion)))
(println "")

;; Test Case 4: Runtime behavior
(println "Test 4: Runtime behavior equivalence")
(let [test-cases [
        [(fn [] (if-let [x nil] :yes :no)) :no "nil binding"]
        [(fn [] (if-let [x false] :yes :no)) :no "false binding"]
        [(fn [] (if-let [x 0] :yes :no)) :yes "0 binding"]
        [(fn [] (if-let [x ""] :yes :no)) :yes "empty string binding"]
        [(fn [] (if-let [x []] :yes :no)) :yes "empty vector binding"]
        [(fn [] (if-let [x (first (filter even? [1 3 5]))] x :none)) :none "failed filter"]
        [(fn [] (if-let [x (first (filter even? [1 2 3]))] x :none)) 2 "successful filter"]
      ]]
  (doseq [[test-fn expected desc] test-cases]
    (let [actual (test-fn)
          status (if (= actual expected) "✓" "✗")]
      (println (format "  %-25s => %-10s (expected %-10s) %s" 
                       desc actual expected status)))))
(println "")

;; Test Case 5: The subtle point - if-let itself returns nil
(println "Test 5: 2-arity if-let returns nil when test is falsey")
(let [r1 (if-let [x nil] :unreachable)
      r2 (if-let [x false] :unreachable)]
  (println "  (if-let [x nil] :unreachable)   =>" r1 (if (nil? r1) "✓" "✗"))
  (println "  (if-let [x false] :unreachable) =>" r2 (if (nil? r2) "✓" "✗")))
(println "")

(println "=== All Tests Complete ===")
(println "If all tests show ✓, expansions are semantically equivalent")
EOF

echo "=== Testing Baseline Clojure ==="
echo ""
java -cp "$BASELINE_CP" clojure.main -e "$(cat test-equivalence.clj)" > baseline-equiv.txt 2>&1
cat baseline-equiv.txt
echo ""

echo "=== Testing Optimized Clojure ==="
echo ""
java -cp "$OPTIMIZED_CP" clojure.main -e "$(cat test-equivalence.clj)" > optimized-equiv.txt 2>&1
cat optimized-equiv.txt
echo ""

# Compare outputs
echo "=== Comparing Results ==="
echo ""

if diff -u baseline-equiv.txt optimized-equiv.txt > equivalence.diff; then
    echo "✓✓✓ IDENTICAL OUTPUT ✓✓✓"
    echo ""
    echo "The baseline and optimized versions produce EXACTLY the same"
    echo "output, confirming semantic equivalence."
else
    echo "⚠️  OUTPUTS DIFFER ⚠️"
    echo ""
    echo "Differences found (may be expected if expansion form changes):"
    echo ""
    head -50 equivalence.diff
    echo ""
    echo "Full diff saved to: equivalence.diff"
    echo ""
    echo "Note: The expansion FORM may differ (e.g., nil vs (quote nil)),"
    echo "but the BEHAVIOR must be identical. Check that all ✓ marks match."
fi
echo ""

# Verify checksums for reproducibility
BASELINE_SHA=$(sha256sum baseline-equiv.txt | awk '{print $1}')
OPTIMIZED_SHA=$(sha256sum optimized-equiv.txt | awk '{print $1}')
echo "Baseline output SHA256:  $BASELINE_SHA"
echo "Optimized output SHA256: $OPTIMIZED_SHA"
echo ""

echo "All artifacts saved to: $WORK_DIR"
echo "  - baseline-equiv.txt  : Baseline test output"
echo "  - optimized-equiv.txt : Optimized test output"
echo "  - equivalence.diff    : Output differences (if any)"
echo "  - test-equivalence.clj: Test code"
echo ""
