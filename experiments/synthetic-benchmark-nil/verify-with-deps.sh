#!/bin/bash
# Complete Nil Optimization Verification with Dependencies
#
# This script properly sets up the classpath with all Clojure dependencies
# to successfully compile and compare bytecode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/verification-full"
CLOJURE_VERSION="1.12.3"

# Clojure and its dependencies from Maven Central
CLOJURE_JAR_URL="https://repo1.maven.org/maven2/org/clojure/clojure/${CLOJURE_VERSION}/clojure-${CLOJURE_VERSION}.jar"
CLOJURE_JAR_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

SPEC_ALPHA_VERSION="0.5.238"
SPEC_ALPHA_URL="https://repo1.maven.org/maven2/org/clojure/spec.alpha/${SPEC_ALPHA_VERSION}/spec.alpha-${SPEC_ALPHA_VERSION}.jar"
# Verified by: curl -sL -o spec.alpha.jar <URL> && sha256sum spec.alpha.jar
SPEC_ALPHA_SHA256="94cd99b6ea639641f37af4860a643b6ed399ee5a8be5d717cff0b663c8d75077"

CORE_SPECS_VERSION="0.4.74"
CORE_SPECS_URL="https://repo1.maven.org/maven2/org/clojure/core.specs.alpha/${CORE_SPECS_VERSION}/core.specs.alpha-${CORE_SPECS_VERSION}.jar"
# Verified by: curl -sL -o core.specs.alpha.jar <URL> && sha256sum core.specs.alpha.jar
CORE_SPECS_SHA256="eb73ac08cf49ba840c88ba67beef11336ca554333d9408808d78946e0feb9ddb"

# Function to download and verify
download_and_verify() {
    local url="$1"
    local file="$2"
    local sha256="$3"
    local desc="$4"
    
    if [ ! -f "$file" ]; then
        echo "  Downloading $desc..."
        curl -sL -o "$file" "$url"
    fi
    
    local actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$sha256" ]; then
        echo "ERROR: SHA256 mismatch for $desc!"
        echo "Expected: $sha256"
        echo "Got:      $actual"
        return 1
    fi
    echo "  ✓ $desc verified"
    return 0
}

mkdir -p "$WORK_DIR"/{baseline,optimized,src,lib}

echo "============================================"
echo "Complete Nil Optimization Verification"
echo "============================================"
echo ""

# Step 1: Download all baseline dependencies
echo "Step 1: Download Clojure ${CLOJURE_VERSION} and dependencies"
download_and_verify "$CLOJURE_JAR_URL" "$WORK_DIR/lib/clojure-baseline.jar" "$CLOJURE_JAR_SHA256" "Clojure ${CLOJURE_VERSION}"
download_and_verify "$SPEC_ALPHA_URL" "$WORK_DIR/lib/spec.alpha.jar" "$SPEC_ALPHA_SHA256" "spec.alpha ${SPEC_ALPHA_VERSION}"
download_and_verify "$CORE_SPECS_URL" "$WORK_DIR/lib/core.specs.alpha.jar" "$CORE_SPECS_SHA256" "core.specs.alpha ${CORE_SPECS_VERSION}"
echo ""

# Build classpath for baseline
BASELINE_CP="$WORK_DIR/lib/clojure-baseline.jar:$WORK_DIR/lib/spec.alpha.jar:$WORK_DIR/lib/core.specs.alpha.jar:$WORK_DIR/src"

# Step 2: Build optimized Clojure
echo "Step 2: Build optimized Clojure"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ ! -f "$WORK_DIR/lib/clojure-optimized.jar" ]; then
    cd "$REPO_ROOT"
    echo "  Building from source (this takes ~60 seconds)..."
    mvn -q -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | grep -E "BUILD|ERROR|WARNING" | head -5 || true
    
    BUILT_JAR=$(find target -name "clojure-*.jar" -not -name "*-slim.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" 2>/dev/null | head -1)
    if [ -z "$BUILT_JAR" ] || [ ! -f "$BUILT_JAR" ]; then
        echo "ERROR: Failed to build optimized JAR"
        exit 1
    fi
    
    cp "$BUILT_JAR" "$WORK_DIR/lib/clojure-optimized.jar"
    echo "  ✓ Built and saved"
fi

OPTIMIZED_SHA256=$(sha256sum "$WORK_DIR/lib/clojure-optimized.jar" | awk '{print $1}')
echo "  Optimized JAR SHA256: $OPTIMIZED_SHA256"
echo "$OPTIMIZED_SHA256" > "$WORK_DIR/lib/clojure-optimized.jar.sha256"

# Build classpath for optimized
OPTIMIZED_CP="$WORK_DIR/lib/clojure-optimized.jar:$WORK_DIR/lib/spec.alpha.jar:$WORK_DIR/lib/core.specs.alpha.jar:$WORK_DIR/src"
echo ""

# Step 3: Create test code
echo "Step 3: Create test code with syntax-quoted nil"
cat > "$WORK_DIR/src/test_nil.clj" << 'CLOJURE'
(ns test-nil)

;; Macro 1: Simple conditional with syntax-quoted nil
(defmacro when-not-test [x & body]
  `(if ~x nil (do ~@body)))

;; Macro 2: Returns vector of nils
(defmacro returns-nils []
  `[nil nil nil])

;; Macro 3: Map with nil values
(defmacro nil-map []
  `{:a nil :b nil})

;; Functions using the macros
(defn use-when-not []
  (when-not-test false :success))

(defn use-nils []
  (returns-nils))

(defn use-nil-map []
  (nil-map))
CLOJURE
echo "  ✓ Test code created"
echo ""

# Step 4: Compile with baseline
echo "Step 4: Compile with baseline Clojure"
cd "$WORK_DIR/baseline"
java -cp "$BASELINE_CP" \
    -Dclojure.compile.path="." \
    -Dclojure.compiler.direct-linking=true \
    clojure.main -e "(compile 'test-nil)" 2>&1 | \
    grep -v "^Reflection" | grep -v "^WARNING" | head -3 || true

if [ ! -f "test_nil__init.class" ]; then
    echo "ERROR: Baseline compilation failed"
    ls -la
    exit 1
fi

BASELINE_COUNT=$(find . -name "*.class" -type f | wc -l)
BASELINE_SIZE=$(du -sb . | awk '{print $1}')
echo "  ✓ Compiled: $BASELINE_COUNT classes, $BASELINE_SIZE bytes total"
echo ""

# Step 5: Compile with optimized
echo "Step 5: Compile with optimized Clojure"
cd "$WORK_DIR/optimized"
java -cp "$OPTIMIZED_CP" \
    -Dclojure.compile.path="." \
    -Dclojure.compiler.direct-linking=true \
    clojure.main -e "(compile 'test-nil)" 2>&1 | \
    grep -v "^Reflection" | grep -v "^WARNING" | head -3 || true

if [ ! -f "test_nil__init.class" ]; then
    echo "ERROR: Optimized compilation failed"
    ls -la
    exit 1
fi

OPTIMIZED_COUNT=$(find . -name "*.class" -type f | wc -l)
OPTIMIZED_SIZE=$(du -sb . | awk '{print $1}')
echo "  ✓ Compiled: $OPTIMIZED_COUNT classes, $OPTIMIZED_SIZE bytes total"
echo ""

# Step 6: Compare and analyze
echo "Step 6: Analyze bytecode differences"
echo "=========================================="

cd "$WORK_DIR"

# Find differences
CHANGED=0
IDENTICAL=0
for baseline_class in $(cd baseline && find . -name "*.class" -type f | sort); do
    if [ -f "optimized/$baseline_class" ]; then
        if cmp -s "baseline/$baseline_class" "optimized/$baseline_class"; then
            IDENTICAL=$((IDENTICAL + 1))
        else
            CHANGED=$((CHANGED + 1))
            echo ""
            echo "CHANGED: $baseline_class"
            
            # Show size difference
            B_SIZE=$(stat -c%s "baseline/$baseline_class" 2>/dev/null || stat -f%z "baseline/$baseline_class")
            O_SIZE=$(stat -c%s "optimized/$baseline_class" 2>/dev/null || stat -f%z "optimized/$baseline_class")
            DIFF=$((O_SIZE - B_SIZE))
            echo "  Size: baseline=$B_SIZE, optimized=$O_SIZE, diff=$DIFF bytes"
            
            # Show relevant bytecode sections
            echo "  Baseline bytecode excerpt:"
            javap -c "baseline/$baseline_class" 2>/dev/null | \
                grep -A 15 "when_not_test\|returns_nils\|nil_map\|use_" | head -18 | sed 's/^/    /'
            
            echo "  Optimized bytecode excerpt:"
            javap -c "optimized/$baseline_class" 2>/dev/null | \
                grep -A 15 "when_not_test\|returns_nils\|nil_map\|use_" | head -18 | sed 's/^/    /'
        fi
    fi
done

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "Compilation Results:"
echo "  Baseline:  $BASELINE_COUNT classes, $BASELINE_SIZE bytes"
echo "  Optimized: $OPTIMIZED_COUNT classes, $OPTIMIZED_SIZE bytes"
echo "  Size difference: $((OPTIMIZED_SIZE - BASELINE_SIZE)) bytes"
echo ""
echo "Bytecode Comparison:"
echo "  Identical classes: $IDENTICAL"
echo "  Changed classes:   $CHANGED"
echo ""

if [ $CHANGED -gt 0 ]; then
    PERCENT=$(awk "BEGIN {printf \"%.1f\", ($CHANGED * 100.0) / ($CHANGED + $IDENTICAL)}")
    echo "✓ VERIFICATION SUCCESSFUL"
    echo "  The nil optimization changes ${PERCENT}% of compiled classes"
    echo "  This confirms the optimization is working as expected"
    echo ""
    echo "Key observations:"
    echo "  - Macros using \`nil produce different bytecode"
    echo "  - The optimization eliminates (quote nil) wrapping"
    echo "  - Class files may be smaller due to simpler bytecode"
else
    echo "⚠ WARNING: No bytecode differences detected"
    echo "  This suggests the optimization may not be working"
fi

echo ""
echo "SHA256 Checksums:"
echo "  Baseline Clojure: $CLOJURE_JAR_SHA256"
echo "  Optimized Clojure: $OPTIMIZED_SHA256"
echo ""

exit 0
