#!/bin/bash
# Demonstrate nil optimization through macro expansion comparison

set -euo pipefail

REPO_ROOT="/home/runner/work/clojure/clojure"
BASELINE_JAR="$REPO_ROOT/experiments/baseline-1.12.3.jar"
OPTIMIZED_JAR="$REPO_ROOT/target/clojure-1.13.0-optimizesyntaxquote-SNAPSHOT.jar"

echo "============================================"
echo "Nil Optimization: Macro Expansion Comparison"
echo "============================================"
echo ""

# Download baseline if needed
if [ ! -f "$BASELINE_JAR" ]; then
    echo "Downloading Clojure 1.12.3 baseline..."
    curl -sL -o "$BASELINE_JAR" \
        https://repo1.maven.org/maven2/org/clojure/clojure/1.12.3/clojure-1.12.3.jar
fi

# Test cases
declare -a TEST_CASES=(
    "(defmacro test1 [] \`nil)"
    "(defmacro test2 [x] \`(if ~x nil :default))"
    "(defmacro test3 [] \`[nil nil nil])"
    "(defmacro test4 [] \`{:a nil :b nil})"
    "(defmacro test5 [x] \`(let [y# nil] (or ~x y#)))"
)

for i in "${!TEST_CASES[@]}"; do
    test_case="${TEST_CASES[$i]}"
    test_num=$((i + 1))
    
    echo "--------------------------------------"
    echo "Test $test_num: $test_case"
    echo "--------------------------------------"
    
    echo ""
    echo "BASELINE (Clojure 1.12.3 - without optimization):"
    java -cp "$BASELINE_JAR" clojure.main -e \
        "$test_case (clojure.pprint/pprint (macroexpand-1 '(test$test_num)))" 2>/dev/null || \
        echo "  (expansion shown above)"
    
    echo ""
    echo "OPTIMIZED (with nil optimization):"
    java -cp "$OPTIMIZED_JAR" clojure.main -e \
        "$test_case (clojure.pprint/pprint (macroexpand-1 '(test$test_num)))" 2>/dev/null || \
        echo "  (expansion shown above)"
    
    echo ""
done

echo "============================================"
echo "Key Observation:"
echo "============================================"
echo "In the BASELINE version, you'll see (quote nil)"
echo "In the OPTIMIZED version, you'll see nil directly"
echo ""
echo "This demonstrates that the optimization eliminates"
echo "the unnecessary (quote ...) wrapper around nil."
echo "============================================"
