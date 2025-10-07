# Quick Start Guide: Running Experiment 1

This guide shows how to quickly run and verify the nil optimization experiment.

## Prerequisites

- Java 21 installed
- Maven 3.x installed
- Git with access to this repository
- Bash shell

## Quick Run (Local)

```bash
# Clone and enter repository
git clone https://github.com/frenchy64/clojure
cd clojure
git checkout copilot/fix-7e4326b0-0cd9-41e6-9b52-cda7d07059b8

# Run the experiment
cd experiments
./01-nil-optimization.sh

# View results
cat results/01-nil-optimization/summary.txt
```

**Expected Duration**: ~3-5 minutes (builds two uberjars)

## Quick Run (GitHub Actions)

1. Go to: https://github.com/frenchy64/clojure/actions
2. Select "Experiment 01 - Nil Optimization" workflow
3. Click "Run workflow" → Select branch → "Run workflow"
4. Wait for completion (~5 minutes)
5. Download "nil-optimization-results" artifact
6. Extract and view `summary.txt`

## Understanding the Output

The script will output:

```
==========================================
Experiment 1: Nil Optimization
==========================================

Building baseline from branch: master
  Size: XXXXXXX bytes

Building optimized from branch: copilot/...
  Size: YYYYYYY bytes

==========================================
RESULTS
==========================================
Baseline size:  XXXXXXX bytes
Optimized size: YYYYYYY bytes
Size reduction: ZZZZZ bytes (0.XXXX%)
```

### Interpreting Results

- **Positive Size Reduction** (Z > 0): Optimization works! Quote wrapping has measurable cost
- **No Change** (Z = 0): nil usage too infrequent, or already optimized by compiler
- **Size Increase** (Z < 0): Unexpected, warrants investigation

## Verifying Reproducibility

Run the experiment multiple times - results should be identical:

```bash
cd experiments

# First run
./01-nil-optimization.sh > run1.log
SIZE1=$(cat results/01-nil-optimization/optimized.size)

# Clean
rm -rf results/

# Second run
./01-nil-optimization.sh > run2.log
SIZE2=$(cat results/01-nil-optimization/optimized.size)

# Compare
echo "Run 1: $SIZE1 bytes"
echo "Run 2: $SIZE2 bytes"
diff run1.log run2.log || echo "Sizes should match: $SIZE1 == $SIZE2"
```

**Expected**: Identical byte counts (builds are deterministic)

## Troubleshooting

### Build Fails

```bash
# Check Java version
java -version  # Should be Java 21

# Clean Maven cache
rm -rf ~/.m2/repository/org/clojure

# Try again
./01-nil-optimization.sh
```

### Script Permission Denied

```bash
chmod +x experiments/01-nil-optimization.sh
```

### Wrong Branch

```bash
# Ensure you're on the right branch
git status
git checkout copilot/fix-7e4326b0-0cd9-41e6-9b52-cda7d07059b8
```

## Advanced: Bytecode Analysis

If size difference is significant, examine bytecode:

```bash
cd experiments/results/01-nil-optimization

# Compare bytecode of a specific class
javap -c baseline-classes/clojure/core\$when*.class > baseline.txt
javap -c optimized-classes/clojure/core\$when*.class > optimized.txt
diff baseline.txt optimized.txt

# Look for:
# - Fewer LDC instructions (constant loading)
# - Simpler method signatures
# - Reduced constant pool entries
```

## Next Steps After Running

1. **Document Results**: Add measured values to experiment tracking
2. **Share Findings**: Update PR with actual measurements
3. **Decide on Phase 2**: Based on results, proceed to empty collection experiments
4. **Iterate**: Apply learnings to remaining 20+ experiments

## Getting Help

- Check `experiments/README.md` for methodology details
- Check `experiments/01-nil-optimization.md` for experiment specifics
- Check `EXPERIMENT_SUMMARY.md` for high-level overview
- Check PR description for comprehensive plan

## Expected Timeline

- **First run**: ~5 minutes (downloads dependencies)
- **Subsequent runs**: ~3 minutes (cached dependencies)
- **In CI**: ~5-7 minutes (fresh environment)
