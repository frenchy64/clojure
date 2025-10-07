#!/bin/bash
# Synthetic Benchmark: Nil Syntax-Quote Compilation
#
# This benchmark compiles a Clojure namespace containing macros that heavily
# use syntax-quoted nil, comparing bytecode between baseline and optimized
# Clojure versions.
#
# METHODOLOGY:
# 1. Download official Clojure 1.12.0 as baseline
# 2. Build optimized Clojure with nil optimization
# 3. Compile test namespace with both versions using direct java -cp calls
# 4. Strip non-deterministic data from compiled classes
# 5. Compare bytecode with javap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
CLOJURE_VERSION="1.12.0"
CLOJURE_JAR_URL="https://repo1.maven.org/maven2/org/clojure/clojure/${CLOJURE_VERSION}/clojure-${CLOJURE_VERSION}.jar"
CLOJURE_JAR_SHA256="7d5eaa5b31d4c5ab12e4df90aeb4e8ba85c1a6cc279120b69f44f3eb1abca9ba"

mkdir -p "$RESULTS_DIR/baseline-classes"
mkdir -p "$RESULTS_DIR/optimized-classes"

echo "=========================================="
echo "Synthetic Benchmark: Nil Optimization"
echo "=========================================="
echo ""

# Step 1: Get baseline Clojure JAR
echo "Step 1: Download baseline Clojure ${CLOJURE_VERSION}..."
if [ ! -f "$RESULTS_DIR/clojure-baseline.jar" ]; then
    curl -L -o "$RESULTS_DIR/clojure-baseline.jar" "$CLOJURE_JAR_URL"
fi

ACTUAL_SHA256=$(sha256sum "$RESULTS_DIR/clojure-baseline.jar" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$CLOJURE_JAR_SHA256" ]; then
    echo "ERROR: SHA256 mismatch!"
    exit 1
fi
echo "✓ Baseline Clojure verified"
echo ""

# Step 2: Get optimized Clojure JAR
echo "Step 2: Get optimized Clojure JAR..."
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if we already built it in the main experiment
if [ -f "$REPO_ROOT/experiments/results/01-nil-optimization/optimized.jar" ]; then
    echo "Using optimized JAR from main experiment"
    cp "$REPO_ROOT/experiments/results/01-nil-optimization/optimized.jar" "$RESULTS_DIR/clojure-optimized.jar"
else
    echo "Building optimized Clojure..."
    cd "$REPO_ROOT"
    mvn -ntp -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | tail -10
    BUILT_JAR=$(find target -name "clojure-*.jar" -not -name "*-slim.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | head -1)
    cp "$BUILT_JAR" "$RESULTS_DIR/clojure-optimized.jar"
    cd "$SCRIPT_DIR"
fi
echo "✓ Optimized Clojure ready"
echo ""

# Step 3: Compile test namespace with baseline Clojure
echo "Step 3: Compile with baseline Clojure..."
cd "$RESULTS_DIR/baseline-classes"

# Use direct java -cp call to compile
java -cp "$RESULTS_DIR/clojure-baseline.jar:$SCRIPT_DIR" \
    -Dclojure.compile.path="$RESULTS_DIR/baseline-classes" \
    -Dclojure.compiler.direct-linking=true \
    clojure.main -e "(compile 'nil-benchmark.core)" 2>&1 | head -10 || true

if [ ! -f "nil_benchmark/core.class" ] && [ ! -f "nil_benchmark/core\$fn__*.class" ]; then
    echo "ERROR: Baseline compilation failed - no class files generated"
    ls -la
    exit 1
fi

echo "✓ Baseline compilation complete"
BASELINE_CLASS_COUNT=$(find . -name "*.class" | wc -l)
echo "  Generated $BASELINE_CLASS_COUNT class files"
echo ""

# Step 4: Compile test namespace with optimized Clojure  
echo "Step 4: Compile with optimized Clojure..."
cd "$RESULTS_DIR/optimized-classes"

java -cp "$RESULTS_DIR/clojure-optimized.jar:$SCRIPT_DIR" \
    -Dclojure.compile.path="$RESULTS_DIR/optimized-classes" \
    -Dclojure.compiler.direct-linking=true \
    clojure.main -e "(compile 'nil-benchmark.core)" 2>&1 | head -10 || true

if [ ! -f "nil_benchmark/core.class" ] && [ ! -f "nil_benchmark/core\$fn__*.class" ]; then
    echo "ERROR: Optimized compilation failed - no class files generated"
    ls -la
    exit 1
fi

echo "✓ Optimized compilation complete"
OPTIMIZED_CLASS_COUNT=$(find . -name "*.class" | wc -l)
echo "  Generated $OPTIMIZED_CLASS_COUNT class files"
echo ""

cd "$SCRIPT_DIR"

# Step 5: Strip non-deterministic data
echo "Step 5: Strip non-deterministic data..."
if command -v strip-nondeterminism &> /dev/null; then
    # Strip all class files
    find "$RESULTS_DIR/baseline-classes" -name "*.class" -exec strip-nondeterminism {} \; 2>/dev/null
    find "$RESULTS_DIR/optimized-classes" -name "*.class" -exec strip-nondeterminism {} \; 2>/dev/null
    echo "✓ Stripped timestamps from class files"
else
    echo "⚠ strip-nondeterminism not available, using as-is"
fi
echo ""

# Step 6: Compare bytecode
echo "Step 6: Compare bytecode..."
echo ""

# Find all baseline classes
TOTAL_CLASSES=0
CHANGED_CLASSES=0
IDENTICAL_CLASSES=0

for baseline_class in $(find "$RESULTS_DIR/baseline-classes" -name "*.class" | sort); do
    TOTAL_CLASSES=$((TOTAL_CLASSES + 1))
    
    # Get relative path
    rel_path=$(echo "$baseline_class" | sed "s|$RESULTS_DIR/baseline-classes/||")
    optimized_class="$RESULTS_DIR/optimized-classes/$rel_path"
    
    if [ ! -f "$optimized_class" ]; then
        echo "⚠ Missing in optimized: $rel_path"
        continue
    fi
    
    # Compare files
    if cmp -s "$baseline_class" "$optimized_class"; then
        IDENTICAL_CLASSES=$((IDENTICAL_CLASSES + 1))
    else
        CHANGED_CLASSES=$((CHANGED_CLASSES + 1))
        echo "Changed: $rel_path"
        
        # Generate bytecode comparison
        classname=$(basename "$rel_path" .class)
        javap -c -v "$baseline_class" > "$RESULTS_DIR/${classname}-baseline.txt" 2>&1
        javap -c -v "$optimized_class" > "$RESULTS_DIR/${classname}-optimized.txt" 2>&1
        
        # Show brief diff summary
        diff -u "$RESULTS_DIR/${classname}-baseline.txt" "$RESULTS_DIR/${classname}-optimized.txt" > "$RESULTS_DIR/${classname}-diff.txt" 2>&1 || true
        DIFF_LINES=$(wc -l < "$RESULTS_DIR/${classname}-diff.txt")
        echo "  Diff: $DIFF_LINES lines (see ${classname}-diff.txt)"
    fi
done

echo ""
echo "=========================================="
echo "Results Summary"
echo "=========================================="
echo "Total classes:     $TOTAL_CLASSES"
echo "Identical:         $IDENTICAL_CLASSES"
echo "Changed:           $CHANGED_CLASSES"
echo ""

# Generate summary report
cat > "$RESULTS_DIR/summary.txt" << EOF
Synthetic Benchmark: Nil Optimization

Test Case: nil-benchmark.core namespace
  - Multiple macros using syntax-quoted nil
  - when-not, defn-with-optional, safe-get, etc.

Compilation:
  Baseline:  Clojure ${CLOJURE_VERSION} (official release)
  Optimized: Current branch with nil optimization
  Method:    Direct java -cp compilation with direct-linking=true

Results:
  Total compiled classes: $TOTAL_CLASSES
  Identical bytecode:     $IDENTICAL_CLASSES
  Changed bytecode:       $CHANGED_CLASSES

Interpretation:
EOF

if [ $CHANGED_CLASSES -eq 0 ]; then
    cat >> "$RESULTS_DIR/summary.txt" << EOF
  No bytecode differences detected. This could mean:
  - The macros don't actually use syntax-quoted nil in compiled output
  - The optimization doesn't affect macro expansion bytecode
  - Need more nil-heavy test cases
EOF
else
    cat >> "$RESULTS_DIR/summary.txt" << EOF
  $CHANGED_CLASSES classes have different bytecode. This confirms:
  - The nil optimization affects compiled macro bytecode
  - Changed compilation strategy is measurable
  - See *-diff.txt files for detailed bytecode changes

Key Changes to Look For:
  - Fewer constant pool entries for 'quote' symbols
  - Simpler instruction sequences for nil handling
  - Reduced method bytecode size
EOF
fi

cat >> "$RESULTS_DIR/summary.txt" << EOF

Files Generated:
  - *-baseline.txt:  Baseline bytecode (javap -c -v)
  - *-optimized.txt: Optimized bytecode (javap -c -v)
  - *-diff.txt:      Side-by-side diff

Next Steps:
  1. Examine diff files for specific instruction changes
  2. Correlate with main experiment JAR size changes
  3. Use as evidence for optimization impact
EOF

cat "$RESULTS_DIR/summary.txt"

echo ""
echo "Benchmark complete. Results in: $RESULTS_DIR/"
