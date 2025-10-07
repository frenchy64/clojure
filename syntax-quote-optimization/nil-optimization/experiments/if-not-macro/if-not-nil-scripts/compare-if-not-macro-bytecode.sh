#!/bin/bash
set -euo pipefail

# This script compares the bytecode of the compiled if-not macro definition
# between baseline Clojure 1.12.3 and the optimized version.
#
# What it verifies: Macro definition bytecode changes (Effect #1)
#
# Dependencies: curl, sha256sum, strip-nondeterminism, javap, unzip, diff
# 
# Expected output: Bytecode differences in core$if_not class

BASELINE_URL="https://repo1.maven.org/maven2/org/clojure/clojure/1.12.3/clojure-1.12.3.jar"
# Verified by: curl -sL $BASELINE_URL | sha256sum
BASELINE_SHA256="cb2a1a3db1c2cd76ef4fa4a545d5a65f10b1b48b7f7672f0a109f5476f057166"

# Path to shared build script
SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBPROJECT_ROOT="$(cd "$SCRIPT_DIR_PATH/../../.." && pwd)"
BUILD_SCRIPT="$SUBPROJECT_ROOT/build-optimized-uberjar.sh"

WORK_DIR="/tmp/if-not-bytecode-compare-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== Comparing if-not Macro Bytecode ==="
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
echo "Downloading baseline Clojure 1.12.3..."
curl -sL "$BASELINE_URL" -o clojure-baseline.jar
verify_sha256 clojure-baseline.jar "$BASELINE_SHA256"
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
echo "✓ Built optimized JAR"
echo ""

# Strip nondeterministic data for fair comparison
echo "Stripping nondeterministic data (timestamps, etc)..."
strip-nondeterminism clojure-baseline.jar > /dev/null 2>&1 || true
strip-nondeterminism clojure-optimized.jar > /dev/null 2>&1 || true

# Record checksums of stripped JARs
BASELINE_STRIPPED_SHA256=$(sha256sum clojure-baseline.jar | awk '{print $1}')
OPTIMIZED_STRIPPED_SHA256=$(sha256sum clojure-optimized.jar | awk '{print $1}')
echo "✓ Baseline stripped SHA256:  $BASELINE_STRIPPED_SHA256"
echo "✓ Optimized stripped SHA256: $OPTIMIZED_STRIPPED_SHA256"
echo ""

# Extract JARs
echo "Extracting class files..."
mkdir -p baseline optimized
cd baseline && unzip -q ../clojure-baseline.jar && cd ..
cd optimized && unzip -q ../clojure-optimized.jar && cd ..
echo ""

# Find the if-not class file
IF_NOT_CLASS="clojure/core\$if_not.class"

if [ ! -f "baseline/$IF_NOT_CLASS" ]; then
    echo "ERROR: Could not find $IF_NOT_CLASS in baseline JAR"
    exit 1
fi

if [ ! -f "optimized/$IF_NOT_CLASS" ]; then
    echo "ERROR: Could not find $IF_NOT_CLASS in optimized JAR"
    exit 1
fi

# Compare the class files directly
echo "=== Direct Binary Comparison ==="
if cmp -s "baseline/$IF_NOT_CLASS" "optimized/$IF_NOT_CLASS"; then
    echo "⚠️  Class files are IDENTICAL (no bytecode changes detected)"
    echo "    This might indicate the optimization doesn't affect if-not,"
    echo "    or the comparison method needs refinement."
else
    echo "✓ Class files are DIFFERENT"
    echo ""
    
    # Show file sizes
    BASELINE_SIZE=$(stat -f%z "baseline/$IF_NOT_CLASS" 2>/dev/null || stat -c%s "baseline/$IF_NOT_CLASS")
    OPTIMIZED_SIZE=$(stat -f%z "optimized/$IF_NOT_CLASS" 2>/dev/null || stat -c%s "optimized/$IF_NOT_CLASS")
    SIZE_DIFF=$((OPTIMIZED_SIZE - BASELINE_SIZE))
    
    echo "  Baseline size:  $BASELINE_SIZE bytes"
    echo "  Optimized size: $OPTIMIZED_SIZE bytes"
    echo "  Difference:     $SIZE_DIFF bytes"
fi
echo ""

# Generate readable bytecode with javap
echo "=== Generating Bytecode Disassembly ==="
javap -c -p -v "baseline/$IF_NOT_CLASS" > if-not-baseline.javap 2>&1
javap -c -p -v "optimized/$IF_NOT_CLASS" > if-not-optimized.javap 2>&1
echo "✓ Generated baseline bytecode: if-not-baseline.javap"
echo "✓ Generated optimized bytecode: if-not-optimized.javap"
echo ""

# Compute checksums of javap output (for reproducibility)
BASELINE_JAVAP_SHA256=$(sha256sum if-not-baseline.javap | awk '{print $1}')
OPTIMIZED_JAVAP_SHA256=$(sha256sum if-not-optimized.javap | awk '{print $1}')
echo "  Baseline javap SHA256:  $BASELINE_JAVAP_SHA256"
echo "  Optimized javap SHA256: $OPTIMIZED_JAVAP_SHA256"
echo ""

# Show the diff
echo "=== Bytecode Differences ==="
echo ""

if diff -u if-not-baseline.javap if-not-optimized.javap > if-not.diff; then
    echo "⚠️  No differences found in javap output"
    echo "    (This might mean optimization doesn't affect if-not,"
    echo "     or javap output is too high-level to show the change)"
else
    echo "✓ Found differences (first 100 lines):"
    echo ""
    head -100 if-not.diff
    echo ""
    echo "Full diff saved to: if-not.diff"
fi
echo ""

# Expected diff (as a heredoc for verification)
read -r -d '' EXPECTED_DIFF <<'EOF' || true
This is a placeholder for the expected diff.
After running this script the first time, examine if-let.diff
and update this heredoc with the actual diff that demonstrates
the nil optimization (e.g., removed GETSTATIC quote, removed RT.list call).

The script will then verify that future runs produce the same diff,
ensuring reproducibility of the experiment.
EOF

# For now, just note that we should verify the diff
echo "=== Next Steps ==="
echo ""
echo "1. Examine the diff above to verify it shows the nil optimization"
echo "2. Look for:"
echo "   - Removed references to 'quote' var"
echo "   - Removed calls to RT.list() or similar"
echo "   - Simplified bytecode around nil handling"
echo "3. Update this script's EXPECTED_DIFF with the actual diff"
echo "4. Future runs will verify reproducibility"
echo ""

echo "All artifacts saved to: $WORK_DIR"
echo "  - if-not-baseline.javap  : Baseline bytecode"
echo "  - if-not-optimized.javap : Optimized bytecode"
echo "  - if-not.diff            : Differences"
echo ""
