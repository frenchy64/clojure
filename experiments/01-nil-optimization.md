# Experiment 1: Nil Optimization

## Overview

This experiment measures the impact of optimizing syntax-quote to treat `nil` as a self-evaluating form using reproducible builds methodology and professional comparison tools.

## Hypothesis

**Before**: `` `nil `` => `(quote nil)` - nil is wrapped in a quote form  
**After**: `` `nil `` => `nil` - nil is returned directly

**Expected Impact**: Reducing unnecessary quote wrapping should:
1. Reduce AOT-compiled bytecode size
2. Simplify code generation for macros using nil
3. Improve consistency (nil behaves like other self-evaluating constants)

## Methodology (Updated)

This experiment uses reproducible builds methodology with efficient comparison:

1. **Baseline**: Official Clojure 1.12.3 JAR from Maven Central (SHA256 verified)
2. **Optimized**: Current branch built with same procedure as releases
3. **Comparison**: Extract and compare class files using checksums for fast identification
4. **Bytecode Analysis**: Detailed `javap` comparison of changed classes

### Key Improvements

- No longer builds from master branch (version drift issues)
- Uses official release as baseline for stability
- Strips timestamps with `strip-nondeterminism` for fair comparison
- Custom efficient class file comparison (faster than diffoscope for CI)
- Separates Java source changes from Clojure compilation changes
- Includes synthetic benchmark for isolated testing

## Running the Experiment

### Prerequisites

```bash
sudo apt-get install strip-nondeterminism
```

### Execute

```bash
cd experiments
./01-nil-optimization.sh
```

## Output Analysis

### Three Categories of Changes

1. **Java Source Changes** (LispReader.java)
   - Files: `LispReader-*-bytecode.txt`, `syntaxQuote-*.txt`
   - Impact: Additional null check in `syntaxQuote()` method
   
2. **Clojure Compilation Strategy Changes**
   - Files: `changed-*-baseline.txt`, `changed-*-optimized.txt`
   - Impact: Different bytecode in macros using syntax-quoted nil
   
3. **Overall Size Impact**
   - Stripped JAR comparison for fair measurement
   - Exact byte count and percentage reduction

### Reports Generated

- `summary.txt` - Complete analysis with interpretation
- `class-differences.txt` - List of all changed/added/removed class files
- `*-bytecode.txt` - Individual class bytecode comparisons
- `optimized-stripped.sha256` - For reproducibility verification

## Synthetic Benchmark

See `experiments/synthetic-benchmark-nil/` for isolated testing of nil-heavy macros using direct `java -cp` compilation (no Maven/CLI).

## Reproducibility

- Baseline JAR verified against: `7d5eaa5b31d4c5ab12e4df90aeb4e8ba85c1a6cc279120b69f44f3eb1abca9ba`
- Optimized stripped JAR SHA256 recorded for verification
- All tools are deterministic
- Results should be identical across runs

## Code Change

### Location
`src/jvm/clojure/lang/LispReader.java` - `SyntaxQuoteReader.syntaxQuote()` method

### Modification

```diff
 else if(form instanceof Keyword
         || form instanceof Number
         || form instanceof Character
-        || form instanceof String)
+        || form instanceof String
+        // `nil => nil, instead of (quote nil)
+        || form == null)
     ret = form;
```

## Rationale

### Why This Optimization Makes Sense

1. **Consistency**: Other self-evaluating forms (strings, numbers, keywords, characters) are already optimized this way
2. **Semantics**: `nil` is a self-evaluating constant in Clojure - `(eval nil) => nil`
3. **Simplicity**: `nil` is simpler than `(quote nil)` - fewer forms to analyze and compile
4. **Common Usage**: nil appears frequently in macros for:
   - Default values
   - Optional arguments
   - Conditional expressions
   - Return values

### Example Macro Impact

```clojure
;; Before optimization
(defmacro when-not [test & body]
  `(if ~test nil (do ~@body)))

;; Expands to (conceptually):
(if test (quote nil) (do ...))

;; After optimization
;; Expands to:
(if test nil (do ...))
```

The difference is subtle but accumulates across many macros in a large codebase.

## Measurement Methodology

### Build Configuration
- Java Version: 21 (for consistency across builds)
- Maven Profile: `local` (includes all dependencies, creates uberjar)
- Direct Linking: Enabled (default in pom.xml)
- AOT Compilation: All Clojure core namespaces

### Compared Artifacts
1. **Baseline**: Master branch (no optimization)
2. **Optimized**: This branch (nil optimization only)

### Metrics
- Primary: Uberjar size (bytes)
- Secondary: Bytecode instruction count (where applicable)

## Running the Experiment

### Locally
```bash
cd experiments
./01-nil-optimization.sh
```

### Via GitHub Actions
Push to any copilot/* branch or trigger workflow manually.

## Expected Results

### Size Impact
Given that nil is used moderately in Clojure core:
- **Best Case**: 100-500 bytes reduction if nil appears in many compiled macros
- **Likely Case**: 10-100 bytes reduction (small but measurable)
- **Worst Case**: No measurable impact (nil usage too infrequent)

### Bytecode Impact
If we examine a macro that uses nil (e.g., `when-not`, `if-not`):
- Fewer LDC or GETSTATIC instructions loading nil
- Simpler constant pool entries
- Potentially better JIT optimization opportunities

## Interpretation Guide

### If Size Decreases (Positive Result)
✓ Optimization reduces bytecode overhead  
✓ Evidence that quote wrapping has measurable cost  
✓ Confirms hypothesis

### If Size Increases (Negative Result)
⚠ Optimization may have unexpected overhead  
⚠ Could indicate constant pool inflation  
⚠ Worth investigating bytecode diff

### If No Change (Neutral Result)
- nil usage may be too infrequent to measure
- Compiler may already optimize (quote nil) => nil
- Size difference below measurement precision (~1-10 bytes)

## Next Steps

After this experiment:
1. Document actual results in results/01-nil-optimization/summary.txt
2. Analyze any significant bytecode differences
3. If successful, proceed to empty collection optimizations
4. If unsuccessful, investigate why and adjust approach

## Related Optimizations

This experiment establishes the baseline for:
- Empty collection optimizations (next phase)
- Understanding constant folding benefits
- Measuring granular optimization impacts

## References

- [Clojure Reader Documentation](https://clojure.org/reference/reader)
- [Syntax Quote Guide](https://clojure.org/guides/weird_characters#syntax-quote)
- [optimize-syntax-quote.md](../doc/optimize-syntax-quote.md)
