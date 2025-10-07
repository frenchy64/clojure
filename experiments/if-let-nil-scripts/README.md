# if-let Nil Optimization Verification Scripts

This directory contains reproducible scripts for verifying the nil optimization in Clojure's syntax-quote, focused on the `if-let` macro.

## Scripts

### 1. `compare-if-let-macro-bytecode.sh`

**Purpose:** Compare bytecode of the compiled `if-let` macro definition

**What it tests:** Effect #1 - Changes to the macro's classfile

**Requirements:**
- curl
- sha256sum
- strip-nondeterminism (optional, for reproducibility)
- javap (part of JDK)
- unzip
- diff
- Maven (for building optimized version)

**Output:**
- Bytecode differences in `core$if_let.class`
- File size comparison
- javap disassembly showing instruction-level changes

**Run:**
```bash
cd /home/runner/work/clojure/clojure
./experiments/if-let-nil-scripts/compare-if-let-macro-bytecode.sh
```

**Expected results:**
- Class file differences showing optimized bytecode
- Smaller optimized classfile (~50-100 bytes)
- Bytecode showing eliminated quote var references

---

### 2. `measure-macro-expansion.sh`

**Purpose:** Measure performance of if-let macro expansion

**What it tests:** Effect #2 - Macro expansion speed

**Requirements:**
- curl
- sha256sum
- java
- Maven (for building optimized version)

**Output:**
- Timing data for 100,000 macro expansions
- Per-expansion time in microseconds
- Performance improvement percentage

**Run:**
```bash
cd /home/runner/work/clojure/clojure
./experiments/if-let-nil-scripts/measure-macro-expansion.sh
```

**Expected results:**
- Faster expansion with optimized version
- Improvement of ~1-10% (depending on JVM warmup, GC, etc.)
- Measurement noise may affect results - run multiple times

---

### 3. `verify-expansion-equivalence.sh`

**Purpose:** Verify semantic equivalence of macro expansions

**What it tests:** Effect #3 - Expansion result behavior

**Requirements:**
- curl
- sha256sum
- java
- Maven (for building optimized version)

**Output:**
- Test results showing identical behavior
- Comparison of expansion forms (may differ in representation)
- Confirmation that all runtime behaviors match

**Run:**
```bash
cd /home/runner/work/clojure/clojure
./experiments/if-let-nil-scripts/verify-expansion-equivalence.sh
```

**Expected results:**
- All test cases pass (✓) for both versions
- Identical runtime behavior
- Possible differences in expansion form representation (nil vs (quote nil))
- Final output should be identical or functionally equivalent

---

## Running All Scripts

To run all verification scripts in sequence:

```bash
cd /home/runner/work/clojure/clojure

echo "=== Bytecode Comparison ==="
./experiments/if-let-nil-scripts/compare-if-let-macro-bytecode.sh
echo ""

echo "=== Performance Measurement ==="
./experiments/if-let-nil-scripts/measure-macro-expansion.sh
echo ""

echo "=== Equivalence Verification ==="
./experiments/if-let-nil-scripts/verify-expansion-equivalence.sh
```

## Understanding the Results

### Script 1: Bytecode Comparison

Shows the **compile-time** impact of the optimization on the `if-let` macro's definition. The optimized version should have:
- Fewer bytecode instructions
- Smaller constant pool
- No references to `quote` var for the nil default

### Script 2: Performance Measurement

Measures the **runtime** cost of macro expansion. When users write `(if-let [x y] ...)`, the compiler must expand this macro. The optimization makes this expansion faster by simplifying the bytecode that executes during expansion.

### Script 3: Equivalence Verification

Confirms that despite bytecode and performance differences, the **semantic behavior** is identical. Both versions:
- Return nil when the test is falsey
- Execute the same conditional logic
- Have the same runtime behavior

## Reproducibility

All scripts:
1. Download and verify Clojure 1.12.3 with SHA256 checksums
2. Build the optimized version from current source
3. Record SHA256 checksums of all intermediate artifacts
4. Generate reproducible comparisons

Running scripts multiple times should produce consistent results (modulo timing variability in script 2).

## Troubleshooting

**"strip-nondeterminism: command not found"**
- Script will continue but may show spurious differences due to timestamps
- Install via: `apt-get install strip-nondeterminism` (Debian/Ubuntu)
- Or use the alternative in script comments

**"No such file or directory: experiments/if-let-nil-scripts/"**
- Make sure you're running from the repository root
- Use absolute paths if needed

**Performance results show no improvement**
- JVM warmup, GC, and measurement noise affect microbenchmarks
- Run multiple times and average results
- Even small improvements (1-5μs) are significant when multiplied across thousands of macro uses

**Maven build fails**
- Ensure you have Java 8+ and Maven 3+
- Check that pom.xml is present in repository root
- Try `mvn clean` first

## See Also

- `../IF_LET_NIL_OPTIMIZATION_ANALYSIS.md` - Detailed analysis document
- `../01-nil-optimization.sh` - Full uberjar comparison
- `../README.md` - Experiments overview
