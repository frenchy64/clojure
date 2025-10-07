# if-not Nil Optimization Verification Scripts

This directory contains reproducible scripts for verifying the nil optimization in Clojure's syntax-quote, focused on the `if-not` macro.

## Scripts

### 1. `compare-if-not-macro-bytecode.sh`

**Purpose:** Compare bytecode of the compiled `if-not` macro definition

**What it tests:** Effect #1 - Changes to the macro's classfile

**Output:**
- Bytecode differences in `core$if_not.class`
- File size comparison
- javap disassembly showing instruction-level changes

### 2. `measure-macro-expansion.sh`

**Purpose:** Measure performance of if-not macro expansion

**What it tests:** Effect #2 - Macro expansion speed

**Output:**
- Timing data for 100,000 macro expansions
- Per-expansion time in microseconds
- Performance improvement percentage

### 3. `verify-expansion-equivalence.sh`

**Purpose:** Verify semantic equivalence of macro expansions

**What it tests:** Effect #3 - Expansion result behavior

**Output:**
- Test results showing identical behavior
- Confirmation that all runtime behaviors match

## See Also

- `../IF_NOT_NIL_OPTIMIZATION_ANALYSIS.adoc` - Detailed analysis document
- `../01-nil-optimization.sh` - Full uberjar comparison
