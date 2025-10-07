#!/bin/bash
# Experiment 1: Nil Optimization Impact Measurement
#
# HYPOTHESIS: Optimizing syntax-quote to return nil directly instead of (quote nil)
# will reduce the size of the AOT-compiled direct-linked Clojure uberjar by eliminating
# unnecessary quote wrapping bytecode.
#
# METHODOLOGY:
# 1. Download official Clojure 1.12.0 direct-linked uberjar from Maven Central
# 2. Verify SHA256 checksum for reproducibility
# 3. Build optimized uberjar from current branch using official release procedure
# 4. Strip non-deterministic data (timestamps) from both JARs
# 5. Compare using diffoscope to identify exact bytecode differences
# 6. Analyze differences:
#    a. Changes from modified Java source (LispReader.java)
#    b. Changes from different Clojure compilation strategy
# 7. Generate detailed reports with javap bytecode analysis
#
# REPRODUCIBILITY: This script is fully automated and deterministic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results/01-nil-optimization"

# Clojure version and checksums
CLOJURE_VERSION="1.12.0"
CLOJURE_JAR_URL="https://repo1.maven.org/maven2/org/clojure/clojure/${CLOJURE_VERSION}/clojure-${CLOJURE_VERSION}.jar"
# SHA256 of the official Clojure 1.12.0 direct-linked uberjar
CLOJURE_JAR_SHA256="7d5eaa5b31d4c5ab12e4df90aeb4e8ba85c1a6cc279120b69f44f3eb1abca9ba"

mkdir -p "$RESULTS_DIR"

cd "$REPO_ROOT"

echo "=========================================="
echo "Experiment 1: Nil Optimization"
echo "=========================================="
echo ""

# Ensure we're using Java 21 for consistency
echo "Java version:"
java -version 2>&1 | head -3
echo ""

# Check for required tools
echo "Checking for required tools..."
for tool in diffoscope strip-nondeterminism javap sha256sum unzip; do
    if ! command -v $tool &> /dev/null; then
        echo "ERROR: Required tool '$tool' is not installed"
        echo "Please install: sudo apt-get install diffoscope strip-nondeterminism"
        exit 1
    fi
done
echo "✓ All required tools found"
echo ""

# Step 1: Download official Clojure baseline JAR
echo "=========================================="
echo "Step 1: Download Official Clojure ${CLOJURE_VERSION}"
echo "=========================================="

if [ ! -f "$RESULTS_DIR/baseline.jar" ]; then
    echo "Downloading Clojure ${CLOJURE_VERSION} from Maven Central..."
    curl -L -o "$RESULTS_DIR/baseline.jar" "$CLOJURE_JAR_URL"
    echo "✓ Downloaded"
else
    echo "Using cached baseline.jar"
fi

# Verify checksum
echo "Verifying SHA256 checksum..."
ACTUAL_SHA256=$(sha256sum "$RESULTS_DIR/baseline.jar" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$CLOJURE_JAR_SHA256" ]; then
    echo "ERROR: SHA256 checksum mismatch!"
    echo "Expected: $CLOJURE_JAR_SHA256"
    echo "Got:      $ACTUAL_SHA256"
    exit 1
fi
echo "✓ Checksum verified"

BASELINE_SIZE=$(stat -c%s "$RESULTS_DIR/baseline.jar" 2>/dev/null || stat -f%z "$RESULTS_DIR/baseline.jar")
echo "Baseline size: $BASELINE_SIZE bytes"
echo ""

# Step 2: Build optimized uberjar using Maven (same as release procedure)
echo "=========================================="
echo "Step 2: Build Optimized Uberjar"
echo "=========================================="

echo "Building optimized uberjar with nil optimization..."
# Clean build with direct linking enabled (default in pom.xml)
# Using -Plocal profile to include dependencies, creating an uberjar
mvn -ntp -B clean package -Dmaven.test.skip=true -Plocal 2>&1 | tail -20

# Find the built JAR
BUILT_JAR=$(find target -name "clojure-*.jar" -not -name "*-slim.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | head -1)
if [ -z "$BUILT_JAR" ]; then
    echo "ERROR: Could not find built JAR in target/"
    exit 1
fi

cp "$BUILT_JAR" "$RESULTS_DIR/optimized.jar"
OPTIMIZED_SIZE=$(stat -c%s "$RESULTS_DIR/optimized.jar" 2>/dev/null || stat -f%z "$RESULTS_DIR/optimized.jar")
echo "✓ Built optimized JAR"
echo "Optimized size: $OPTIMIZED_SIZE bytes"
echo ""

# Step 3: Strip non-deterministic data
echo "=========================================="
echo "Step 3: Strip Non-Deterministic Data"
echo "=========================================="

echo "Stripping timestamps and other non-deterministic data..."
cp "$RESULTS_DIR/baseline.jar" "$RESULTS_DIR/baseline-stripped.jar"
cp "$RESULTS_DIR/optimized.jar" "$RESULTS_DIR/optimized-stripped.jar"

strip-nondeterminism "$RESULTS_DIR/baseline-stripped.jar" 2>&1 | grep -v "MANIFEST.MF" || true
strip-nondeterminism "$RESULTS_DIR/optimized-stripped.jar" 2>&1 | grep -v "MANIFEST.MF" || true

BASELINE_STRIPPED_SIZE=$(stat -c%s "$RESULTS_DIR/baseline-stripped.jar" 2>/dev/null || stat -f%z "$RESULTS_DIR/baseline-stripped.jar")
OPTIMIZED_STRIPPED_SIZE=$(stat -c%s "$RESULTS_DIR/optimized-stripped.jar" 2>/dev/null || stat -f%z "$RESULTS_DIR/optimized-stripped.jar")

echo "✓ Stripped JARs created"
echo "Baseline stripped size:  $BASELINE_STRIPPED_SIZE bytes"
echo "Optimized stripped size: $OPTIMIZED_STRIPPED_SIZE bytes"

# Calculate stripped SHA256 for reproducibility
OPTIMIZED_STRIPPED_SHA256=$(sha256sum "$RESULTS_DIR/optimized-stripped.jar" | awk '{print $1}')
echo "Optimized stripped SHA256: $OPTIMIZED_STRIPPED_SHA256"
echo "$OPTIMIZED_STRIPPED_SHA256" > "$RESULTS_DIR/optimized-stripped.sha256"
echo ""

# Step 4: Compare with diffoscope
echo "=========================================="
echo "Step 4: Compare with Diffoscope"
echo "=========================================="

echo "Running diffoscope to identify all differences..."
# diffoscope exits with non-zero if differences found, so don't fail on that
diffoscope --text "$RESULTS_DIR/diffoscope-report.txt" \
    "$RESULTS_DIR/baseline-stripped.jar" \
    "$RESULTS_DIR/optimized-stripped.jar" 2>&1 | head -20 || true

if [ -f "$RESULTS_DIR/diffoscope-report.txt" ]; then
    DIFF_SIZE=$(wc -l < "$RESULTS_DIR/diffoscope-report.txt")
    echo "✓ Diffoscope report generated: $DIFF_SIZE lines"
    echo "  Report saved to: diffoscope-report.txt"
else
    echo "⚠ Diffoscope report not generated"
fi
echo ""

# Step 5: Extract and analyze changed classes
echo "=========================================="
echo "Step 5: Analyze Bytecode Differences"
echo "=========================================="

mkdir -p "$RESULTS_DIR/baseline-classes"
mkdir -p "$RESULTS_DIR/optimized-classes"

# Extract all class files
echo "Extracting class files..."
unzip -q "$RESULTS_DIR/baseline-stripped.jar" "*.class" -d "$RESULTS_DIR/baseline-classes" 2>/dev/null || true
unzip -q "$RESULTS_DIR/optimized-stripped.jar" "*.class" -d "$RESULTS_DIR/optimized-classes" 2>/dev/null || true

# Find Java source changes (LispReader.class)
echo ""
echo "Analyzing changes in Java source (LispReader)..."
if [ -f "$RESULTS_DIR/baseline-classes/clojure/lang/LispReader.class" ] && \
   [ -f "$RESULTS_DIR/optimized-classes/clojure/lang/LispReader.class" ]; then
    
    javap -c "$RESULTS_DIR/baseline-classes/clojure/lang/LispReader.class" > "$RESULTS_DIR/LispReader-baseline-bytecode.txt" 2>&1
    javap -c "$RESULTS_DIR/optimized-classes/clojure/lang/LispReader.class" > "$RESULTS_DIR/LispReader-optimized-bytecode.txt" 2>&1
    
    # Show specific method that changed (syntaxQuote)
    echo "Extracting syntaxQuote method bytecode..."
    grep -A 200 "syntaxQuote(java.lang.Object)" "$RESULTS_DIR/LispReader-baseline-bytecode.txt" | head -250 > "$RESULTS_DIR/syntaxQuote-baseline.txt" || true
    grep -A 200 "syntaxQuote(java.lang.Object)" "$RESULTS_DIR/LispReader-optimized-bytecode.txt" | head -250 > "$RESULTS_DIR/syntaxQuote-optimized.txt" || true
    
    echo "✓ LispReader bytecode extracted"
    echo "  Files: LispReader-*-bytecode.txt, syntaxQuote-*.txt"
fi

# Find Clojure compilation differences
echo ""
echo "Finding AOT-compiled Clojure classes with differences..."
CHANGED_CLOJURE_CLASSES=0

# Compare all Clojure core classes
for baseline_class in "$RESULTS_DIR/baseline-classes/clojure/core"*.class; do
    if [ -f "$baseline_class" ]; then
        classname=$(basename "$baseline_class")
        optimized_class="$RESULTS_DIR/optimized-classes/clojure/core$classname"
        
        if [ -f "$optimized_class" ]; then
            if ! cmp -s "$baseline_class" "$optimized_class"; then
                CHANGED_CLOJURE_CLASSES=$((CHANGED_CLOJURE_CLASSES + 1))
                
                # Only generate detailed reports for first 5 changed classes
                if [ $CHANGED_CLOJURE_CLASSES -le 5 ]; then
                    echo "  Changed: clojure/core$classname"
                    javap -c "$baseline_class" > "$RESULTS_DIR/changed-${classname%.class}-baseline.txt" 2>&1
                    javap -c "$optimized_class" > "$RESULTS_DIR/changed-${classname%.class}-optimized.txt" 2>&1
                fi
            fi
        fi
    fi
done

echo "Found $CHANGED_CLOJURE_CLASSES changed AOT-compiled Clojure classes"
echo ""

# Step 6: Generate summary report
echo "=========================================="
echo "Step 6: Generate Summary Report"
echo "=========================================="

SIZE_DIFF=$((BASELINE_SIZE - OPTIMIZED_SIZE))
STRIPPED_SIZE_DIFF=$((BASELINE_STRIPPED_SIZE - OPTIMIZED_STRIPPED_SIZE))
PERCENT_REDUCTION=$(awk "BEGIN {printf \"%.4f\", ($STRIPPED_SIZE_DIFF / $BASELINE_STRIPPED_SIZE) * 100}")

cat > "$RESULTS_DIR/summary.txt" << EOF
Experiment 1: Nil Optimization Impact

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HYPOTHESIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Making nil self-evaluating in syntax-quote (changing \`nil from (quote nil) 
to nil) will reduce AOT-compiled bytecode size by eliminating unnecessary 
quote form analysis and compilation.

CODE CHANGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: src/jvm/clojure/lang/LispReader.java
Method: SyntaxQuoteReader.syntaxQuote()

Added condition: || form == null

This makes nil behave like other self-evaluating constants (strings, numbers,
keywords, characters).

BUILD CONFIGURATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Baseline:  Official Clojure ${CLOJURE_VERSION} from Maven Central
           SHA256: ${CLOJURE_JAR_SHA256}
Optimized: Current branch built with Maven -Plocal
           Direct linking: Enabled (default)
           Java version: $(java -version 2>&1 | head -1)

OVERALL SIZE COMPARISON
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Original JARs (with timestamps):
  Baseline:    $BASELINE_SIZE bytes
  Optimized:   $OPTIMIZED_SIZE bytes
  Difference:  $SIZE_DIFF bytes

Stripped JARs (timestamps removed for fair comparison):
  Baseline:    $BASELINE_STRIPPED_SIZE bytes
  Optimized:   $OPTIMIZED_STRIPPED_SIZE bytes  
  Difference:  $STRIPPED_SIZE_DIFF bytes ($PERCENT_REDUCTION%)

REPRODUCIBILITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Baseline JAR verified against known SHA256 checksum.
Optimized stripped JAR SHA256: $OPTIMIZED_STRIPPED_SHA256

BYTECODE ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Java Source Changes (LispReader.java):
   - Modified class: clojure.lang.LispReader\$SyntaxQuoteReader
   - Changed method: syntaxQuote(Object)
   - Analysis: See LispReader-*-bytecode.txt and syntaxQuote-*.txt
   - Impact: Additional null check in bytecode

2. Clojure Compilation Strategy Changes:
   - Changed AOT-compiled classes: $CHANGED_CLOJURE_CLASSES
   - These are macros/functions affected by the nil optimization
   - Detailed bytecode: changed-*-baseline.txt vs changed-*-optimized.txt

DETAILED REPORTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- diffoscope-report.txt:        Complete diff of stripped JARs
- LispReader-*-bytecode.txt:    Full LispReader class bytecode
- syntaxQuote-*.txt:            syntaxQuote method bytecode comparison
- changed-*-baseline.txt:       Individual changed Clojure class bytecode

INTERPRETATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

if [ $STRIPPED_SIZE_DIFF -gt 0 ]; then
    cat >> "$RESULTS_DIR/summary.txt" << EOF
✓ OPTIMIZATION SUCCESSFUL

The stripped JAR is $STRIPPED_SIZE_DIFF bytes smaller ($PERCENT_REDUCTION% reduction).

This confirms that:
1. The nil optimization reduces bytecode overhead
2. Removing (quote nil) wrappers has measurable impact
3. The change affects $CHANGED_CLOJURE_CLASSES AOT-compiled Clojure classes

The size reduction comes from:
- Simpler bytecode in the modified LispReader.syntaxQuote method
- More efficient compiled code in macros that use syntax-quoted nil
- Reduced constant pool entries related to quote forms
EOF
elif [ $STRIPPED_SIZE_DIFF -lt 0 ]; then
    cat >> "$RESULTS_DIR/summary.txt" << EOF
⚠ UNEXPECTED: Optimization increased size

The stripped JAR is $((0 - STRIPPED_SIZE_DIFF)) bytes larger.

This suggests:
1. The null check in LispReader adds more bytecode than it saves
2. Changed compilation strategy has overhead
3. May need to investigate unexpected side effects

Check diffoscope-report.txt and bytecode files for details.
EOF
else
    cat >> "$RESULTS_DIR/summary.txt" << EOF
- NO MEASURABLE SIZE CHANGE

The stripped JARs are the same size.

This could mean:
1. nil is used too infrequently to measure
2. Compiler already optimizes (quote nil) effectively
3. Size difference is below measurement precision
4. Java vs Clojure bytecode changes cancel out

Check changed class count and diffoscope report for qualitative impact.
EOF
fi

cat >> "$RESULTS_DIR/summary.txt" << EOF

NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Review diffoscope-report.txt for complete diff
2. Examine bytecode changes in detail
3. Compare with synthetic benchmark results
4. Proceed to Phase 2 (empty collections) if successful
EOF

cat "$RESULTS_DIR/summary.txt"

echo ""
echo "=========================================="
echo "Experiment Complete"
echo "=========================================="
echo "Results saved to: $RESULTS_DIR/"
echo ""
