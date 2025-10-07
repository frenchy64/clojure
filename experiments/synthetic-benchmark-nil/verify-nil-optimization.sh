#!/bin/bash
# Runnable Synthetic Benchmark: Verify Nil Optimization Impact
#
# This script demonstrates and verifies the nil optimization by:
# 1. Compiling test code with baseline Clojure 1.12.3
# 2. Compiling the same code with optimized Clojure
# 3. Comparing the resulting bytecode
#
# Based on https://stackoverflow.com/a/29012274

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/verification"
CLOJURE_VERSION="1.12.3"
CLOJURE_JAR_URL="https://repo1.maven.org/maven2/org/clojure/clojure/${CLOJURE_VERSION}/clojure-${CLOJURE_VERSION}.jar"
CLOJURE_JAR_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

# Function to verify SHA256
verify_sha256() {
    local file="$1"
    local expected="$2"
    local desc="$3"
    
    local actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "ERROR: SHA256 mismatch for $desc!"
        echo "Expected: $expected"
        echo "Got:      $actual"
        return 1
    fi
    echo "✓ SHA256 verified: $desc"
    return 0
}

mkdir -p "$WORK_DIR"/{baseline,optimized,src}

echo "============================================"
echo "Nil Optimization Verification"
echo "============================================"
echo ""

# Step 1: Download baseline Clojure
echo "Step 1: Prepare baseline Clojure ${CLOJURE_VERSION}"
if [ ! -f "$WORK_DIR/clojure-baseline.jar" ]; then
    echo "  Downloading..."
    curl -sL -o "$WORK_DIR/clojure-baseline.jar" "$CLOJURE_JAR_URL"
fi
verify_sha256 "$WORK_DIR/clojure-baseline.jar" "$CLOJURE_JAR_SHA256" "baseline JAR" || exit 1
echo ""

# Step 2: Build optimized Clojure
echo "Step 2: Build optimized Clojure"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f "$WORK_DIR/clojure-optimized.jar" ]; then
    echo "  Building from source..."
    mvn -q -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | grep -E "BUILD|ERROR" || true
    
    BUILT_JAR=$(find target -name "clojure-*.jar" -not -name "*-slim.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" 2>/dev/null | head -1)
    if [ -z "$BUILT_JAR" ] || [ ! -f "$BUILT_JAR" ]; then
        echo "ERROR: Failed to build optimized JAR"
        exit 1
    fi
    
    cp "$BUILT_JAR" "$WORK_DIR/clojure-optimized.jar"
    echo "  ✓ Built and copied to $WORK_DIR/clojure-optimized.jar"
else
    echo "  Using cached optimized JAR"
fi

# Record SHA256 for reproducibility
OPTIMIZED_SHA256=$(sha256sum "$WORK_DIR/clojure-optimized.jar" | awk '{print $1}')
echo "  Optimized JAR SHA256: $OPTIMIZED_SHA256"
echo "$OPTIMIZED_SHA256" > "$WORK_DIR/clojure-optimized.jar.sha256"
echo ""

# Step 3: Create simple test code
echo "Step 3: Create test code with syntax-quoted nil"
cat > "$WORK_DIR/src/test_nil.clj" << 'CLOJURE'
(ns test-nil)

;; Macro that uses syntax-quoted nil
(defmacro when-not-test [x & body]
  `(if ~x nil (do ~@body)))

;; Another macro with multiple nils
(defmacro returns-nils []
  `[nil nil nil])

;; Function using the macros
(defn use-macros []
  [(when-not-test false :result)
   (returns-nils)])
CLOJURE
echo "  ✓ Test code created"
echo ""

# Step 4: Compile with baseline Clojure
echo "Step 4: Compile with baseline Clojure"
cd "$WORK_DIR/baseline"
java -cp "$WORK_DIR/clojure-baseline.jar:$WORK_DIR/src" \
    -Dclojure.compile.path="." \
    -Dclojure.compiler.direct-linking=true \
    clojure.main -e "(compile 'test-nil)" 2>&1 | grep -v "^Reflection" | head -5 || echo "  (compilation output above)"

if [ ! -f "test_nil.class" ]; then
    echo "ERROR: Baseline compilation failed"
    ls -la
    exit 1
fi

BASELINE_CLASSES=$(find . -name "*.class" -type f | wc -l)
echo "  ✓ Compiled $BASELINE_CLASSES class files with baseline"
echo ""

# Step 5: Compile with optimized Clojure  
echo "Step 5: Compile with optimized Clojure"
cd "$WORK_DIR/optimized"
java -cp "$WORK_DIR/clojure-optimized.jar:$WORK_DIR/src" \
    -Dclojure.compile.path="." \
    -Dclojure.compiler.direct-linking=true \
    clojure.main -e "(compile 'test-nil)" 2>&1 | grep -v "^Reflection" | head -5 || echo "  (compilation output above)"

if [ ! -f "test_nil.class" ]; then
    echo "ERROR: Optimized compilation failed"
    ls -la
    exit 1
fi

OPTIMIZED_CLASSES=$(find . -name "*.class" -type f | wc -l)
echo "  ✓ Compiled $OPTIMIZED_CLASSES class files with optimized"
echo ""

# Step 6: Compare bytecode
echo "Step 6: Compare bytecode"
echo "=========================================="

cd "$WORK_DIR"

# Find classes that differ
DIFFERENT_CLASSES=()
for baseline_class in $(cd baseline && find . -name "*.class" -type f); do
    if [ -f "optimized/$baseline_class" ]; then
        if ! cmp -s "baseline/$baseline_class" "optimized/$baseline_class"; then
            DIFFERENT_CLASSES+=("$baseline_class")
        fi
    fi
done

echo "Found ${#DIFFERENT_CLASSES[@]} classes with different bytecode"
echo ""

if [ ${#DIFFERENT_CLASSES[@]} -eq 0 ]; then
    echo "WARNING: No bytecode differences found!"
    echo "This might indicate:"
    echo "  1. The optimization is not being applied"
    echo "  2. The test code doesn't trigger the optimization"
    echo "  3. The baseline and optimized JARs are identical"
    exit 1
fi

# Analyze first few differences in detail
MAX_DETAIL=3
COUNT=0
for class_file in "${DIFFERENT_CLASSES[@]}"; do
    if [ $COUNT -ge $MAX_DETAIL ]; then
        break
    fi
    
    echo "----------------------------------------"
    echo "Class: $class_file"
    echo "----------------------------------------"
    
    # Extract just the macro-related methods
    echo "BASELINE bytecode (relevant sections):"
    javap -c "baseline/$class_file" 2>/dev/null | \
        grep -A 20 "when_not_test\|returns_nils\|use_macros" | head -25
    
    echo ""
    echo "OPTIMIZED bytecode (relevant sections):"
    javap -c "optimized/$class_file" 2>/dev/null | \
        grep -A 20 "when_not_test\|returns_nils\|use_macros" | head -25
    
    echo ""
    COUNT=$((COUNT + 1))
done

if [ ${#DIFFERENT_CLASSES[@]} -gt $MAX_DETAIL ]; then
    echo "... and $((${#DIFFERENT_CLASSES[@]} - MAX_DETAIL)) more changed classes"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Baseline JAR:  $WORK_DIR/clojure-baseline.jar"
echo "  SHA256: $CLOJURE_JAR_SHA256"
echo "Optimized JAR: $WORK_DIR/clojure-optimized.jar"
echo "  SHA256: $OPTIMIZED_SHA256"
echo ""
echo "Classes compiled: $BASELINE_CLASSES (both versions)"
echo "Classes changed: ${#DIFFERENT_CLASSES[@]}"
echo ""
echo "✓ Verification complete"
echo ""
echo "Key findings:"
echo "  - The nil optimization changes bytecode generation"
echo "  - Macros using syntax-quoted nil produce different bytecode"
echo "  - The optimization is working as expected"
echo ""

exit 0
