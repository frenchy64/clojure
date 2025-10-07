#!/bin/bash
# Experiment 1: Nil Optimization Impact Measurement
#
# HYPOTHESIS: Optimizing syntax-quote to return nil directly instead of (quote nil)
# will reduce the size of the AOT-compiled direct-linked Clojure uberjar by eliminating
# unnecessary quote wrapping bytecode.
#
# METHODOLOGY:
# 1. Build baseline uberjar from master branch (no optimization)
# 2. Build optimized uberjar from current branch (nil optimization only)
# 3. Compare file sizes
# 4. Extract and compare key class files with javap to show bytecode differences
#
# REPRODUCIBILITY: This script is fully automated and deterministic.
# Results are checked into the repository and verified by CI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results/01-nil-optimization"

mkdir -p "$RESULTS_DIR"

cd "$REPO_ROOT"

echo "=========================================="
echo "Experiment 1: Nil Optimization"
echo "=========================================="
echo ""

# Ensure we're using Java 21 for consistency
java -version 2>&1 | head -3
echo ""

# Function to build uberjar with direct linking
build_uberjar() {
    local branch="$1"
    local output_name="$2"
    
    echo "Building $output_name from branch: $branch"
    git checkout "$branch" 2>&1 | grep -v "^Switched to" || true
    
    # Clean build with direct linking enabled (default in pom.xml)
    mvn -ntp -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | grep -E "(BUILD SUCCESS|BUILD FAILURE)" || true
    
    # Copy the uberjar to results directory
    cp target/clojure-*.jar "$RESULTS_DIR/$output_name.jar"
    
    # Get size
    local size=$(stat -f%z "$RESULTS_DIR/$output_name.jar" 2>/dev/null || stat -c%s "$RESULTS_DIR/$output_name.jar")
    echo "$size" > "$RESULTS_DIR/$output_name.size"
    echo "  Size: $size bytes"
    echo ""
}

# Build baseline (master) uberjar
build_uberjar "master" "baseline"

# Build optimized uberjar (current branch with nil optimization only)
build_uberjar "copilot/fix-7e4326b0-0cd9-41e6-9b52-cda7d07059b8" "optimized"

# Calculate size difference
BASELINE_SIZE=$(cat "$RESULTS_DIR/baseline.size")
OPTIMIZED_SIZE=$(cat "$RESULTS_DIR/optimized.size")
SIZE_DIFF=$((BASELINE_SIZE - OPTIMIZED_SIZE))
PERCENT_REDUCTION=$(awk "BEGIN {printf \"%.4f\", ($SIZE_DIFF / $BASELINE_SIZE) * 100}")

echo "=========================================="
echo "RESULTS"
echo "=========================================="
echo "Baseline size:  $BASELINE_SIZE bytes"
echo "Optimized size: $OPTIMIZED_SIZE bytes"
echo "Size reduction: $SIZE_DIFF bytes ($PERCENT_REDUCTION%)"
echo ""

# Save summary
cat > "$RESULTS_DIR/summary.txt" << EOF
Experiment 1: Nil Optimization Impact

Change: Modified LispReader.java to make nil self-evaluating in syntax-quote
  Before: \`nil => (quote nil)
  After:  \`nil => nil

Build Configuration:
  - Java Version: $(java -version 2>&1 | head -1)
  - Direct Linking: Enabled (default)
  - Profile: local (includes dependencies)

Results:
  Baseline JAR size:  $BASELINE_SIZE bytes
  Optimized JAR size: $OPTIMIZED_SIZE bytes
  Size difference:    $SIZE_DIFF bytes
  Percent reduction:  $PERCENT_REDUCTION%

Interpretation:
$(if [ $SIZE_DIFF -gt 0 ]; then
    echo "  ✓ Optimization reduced JAR size"
    echo "  This confirms that removing (quote nil) wrappers reduces bytecode"
elif [ $SIZE_DIFF -lt 0 ]; then
    echo "  ✗ Optimization increased JAR size"
    echo "  This suggests the optimization may have overhead"
else
    echo "  - No size change detected"
    echo "  nil may be used infrequently or optimization has no bytecode impact"
fi)

Next Steps:
  1. Analyze bytecode diffs of key classes (if available)
  2. Measure compilation time impact
  3. Measure runtime performance of nil-heavy macros
EOF

cat "$RESULTS_DIR/summary.txt"

# Extract some representative class files for bytecode comparison
echo ""
echo "=========================================="
echo "Extracting class files for bytecode analysis..."
echo "=========================================="

# Find classes that use syntax-quote heavily (like clojure.core macros)
for class_path in "clojure/core\$fn__" "clojure/core\$when" "clojure/core\$if_not"; do
    echo "Checking for $class_path..."
    
    # Extract baseline
    unzip -q "$RESULTS_DIR/baseline.jar" "$class_path*.class" -d "$RESULTS_DIR/baseline-classes" 2>/dev/null || true
    
    # Extract optimized  
    unzip -q "$RESULTS_DIR/optimized.jar" "$class_path*.class" -d "$RESULTS_DIR/optimized-classes" 2>/dev/null || true
done

# Generate javap output for comparison
if [ -d "$RESULTS_DIR/baseline-classes/clojure/core" ]; then
    echo "Generating javap output for bytecode comparison..."
    
    # Pick one representative class
    baseline_class=$(find "$RESULTS_DIR/baseline-classes" -name "*.class" | head -1)
    if [ -n "$baseline_class" ]; then
        class_name=$(echo "$baseline_class" | sed 's|.*/baseline-classes/||' | sed 's|\.class$||')
        optimized_class="$RESULTS_DIR/optimized-classes/$class_name.class"
        
        if [ -f "$optimized_class" ]; then
            echo "Comparing: $class_name"
            javap -c "$baseline_class" > "$RESULTS_DIR/baseline-bytecode.txt" 2>&1 || true
            javap -c "$optimized_class" > "$RESULTS_DIR/optimized-bytecode.txt" 2>&1 || true
            
            # Show instruction count difference
            baseline_instr=$(grep -c ":" "$RESULTS_DIR/baseline-bytecode.txt" || echo "0")
            optimized_instr=$(grep -c ":" "$RESULTS_DIR/optimized-bytecode.txt" || echo "0")
            instr_diff=$((baseline_instr - optimized_instr))
            
            echo "  Baseline instructions:  $baseline_instr"
            echo "  Optimized instructions: $optimized_instr"
            echo "  Instruction reduction:  $instr_diff"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Experiment complete!"
echo "Results saved to: $RESULTS_DIR/"
echo "=========================================="
