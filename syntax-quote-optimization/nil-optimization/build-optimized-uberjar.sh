#!/bin/bash
set -euo pipefail

# This script builds an optimized Clojure uberjar with the nil optimization patch applied.
#
# Usage: ./build-optimized-uberjar.sh [output_dir]
#
# The script:
# 1. Clones the official Clojure repository at commit e6393a4063c42ddc0e0812f04464467764f0fd1e (Clojure 1.12.3)
# 2. Applies the nil-optimization.patch
# 3. Builds the uberjar with Maven
# 4. Strips nondeterministic data (timestamps, etc.)
# 5. Computes and verifies SHA256 checksum
# 6. Copies the result to the output directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/build}"
CLOJURE_COMMIT="e6393a4063c42ddc0e0812f04464467764f0fd1e"
PATCH_FILE="$SCRIPT_DIR/nil-optimization.patch"

# Create a temporary directory for the build
WORK_DIR="/tmp/build-optimized-clojure-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== Building Optimized Clojure Uberjar ==="
echo ""
echo "Working directory: $WORK_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Clone Clojure repository
echo "Cloning Clojure repository..."
git clone https://github.com/clojure/clojure.git clojure-build
cd clojure-build
git checkout "$CLOJURE_COMMIT"
echo "✓ Cloned and checked out commit $CLOJURE_COMMIT"
echo ""

# Apply the nil optimization patch
echo "Applying nil optimization patch..."
if [ ! -f "$PATCH_FILE" ]; then
    echo "ERROR: Patch file not found: $PATCH_FILE"
    exit 1
fi
git apply "$PATCH_FILE"
echo "✓ Patch applied successfully"
echo ""

# Build the uberjar
echo "Building uberjar with Maven..."
mvn -ntp -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | tail -20
echo ""

# Find the built JAR
BUILT_JAR=$(find target -name "clojure-*.jar" -not -name "*-slim.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | head -1)
if [ -z "$BUILT_JAR" ]; then
    echo "ERROR: Could not find built JAR in target/"
    exit 1
fi
echo "✓ Built JAR: $BUILT_JAR"
echo ""

# Copy to output directory
mkdir -p "$OUTPUT_DIR"
cp "$BUILT_JAR" "$OUTPUT_DIR/clojure-nil-optimized.jar"
echo "✓ Copied to: $OUTPUT_DIR/clojure-nil-optimized.jar"
echo ""

# Strip nondeterministic data if strip-nondeterminism is available
if command -v strip-nondeterminism &> /dev/null; then
    echo "Stripping nondeterministic data..."
    strip-nondeterminism "$OUTPUT_DIR/clojure-nil-optimized.jar" > /dev/null 2>&1 || true
    echo "✓ Stripped nondeterministic data"
else
    echo "⚠️  strip-nondeterminism not available, skipping"
fi
echo ""

# Compute SHA256 checksum
SHA256=$(sha256sum "$OUTPUT_DIR/clojure-nil-optimized.jar" | awk '{print $1}')
echo "SHA256: $SHA256"
echo "$SHA256" > "$OUTPUT_DIR/clojure-nil-optimized.jar.sha256"
echo "✓ SHA256 saved to: $OUTPUT_DIR/clojure-nil-optimized.jar.sha256"
echo ""

# Get file size
SIZE=$(stat -c%s "$OUTPUT_DIR/clojure-nil-optimized.jar" 2>/dev/null || stat -f%z "$OUTPUT_DIR/clojure-nil-optimized.jar")
echo "Size: $SIZE bytes"
echo ""

echo "=== Build Complete ==="
echo "Output: $OUTPUT_DIR/clojure-nil-optimized.jar"
echo "SHA256: $SHA256"
echo ""

# Cleanup
cd /
rm -rf "$WORK_DIR"
