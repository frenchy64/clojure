# Syntax-Quote Optimization Experiments

This directory contains scripts and results for systematic experiments measuring the impact of syntax-quote optimizations in Clojure.

## Overview

The goal is to break down the comprehensive syntax-quote optimizations from the `optimize-syntax-quote` branch into atomic, measurable pieces. Each experiment:

1. Isolates a single optimization
2. Measures its impact on the AOT-compiled direct-linked Clojure uberjar
3. Provides reproducible scripts and CI workflows
4. Documents bytecode-level changes when significant

## Experiment Structure

Each experiment follows a consistent structure:

```
experiments/
├── 01-nil-optimization.sh          # Experiment script
├── results/
│   └── 01-nil-optimization/        # Results directory
│       ├── summary.txt              # Human-readable summary
│       ├── baseline.jar             # Master branch build
│       ├── optimized.jar            # Optimized branch build
│       ├── baseline.size            # Baseline size in bytes
│       ├── optimized.size           # Optimized size in bytes
│       ├── baseline-bytecode.txt    # Sample bytecode (if available)
│       └── optimized-bytecode.txt   # Sample bytecode (if available)
└── README.md                        # This file
```

## Running Experiments

### Prerequisites

- Java 21 (for consistency)
- Maven 3.x
- Git
- Bash

### Running Locally

```bash
cd experiments
./01-nil-optimization.sh
```

### Running via GitHub Actions

Experiments run automatically on:
- Push to copilot/* branches
- Pull requests
- Manual workflow dispatch

Results are available as workflow artifacts.

## Experiments

### Experiment 1: Nil Optimization

**Status**: ✓ Implemented  
**Hypothesis**: Making nil self-evaluating in syntax-quote reduces bytecode  
**Change**: `'nil` => nil instead of (quote nil)  
**Script**: `01-nil-optimization.sh`  
**Workflow**: `.github/workflows/experiment-01-nil.yml`

**Expected Impact**:
- Small reduction in uberjar size
- Fewer bytecode instructions in macros using nil
- Simpler code generation for nil constants

### Future Experiments

See the comprehensive plan in the PR description for upcoming experiments on:
- Empty collections (vectors, lists, sets, maps)
- Constant collections
- Mixed constant/unquote collections
- Splicing optimizations
- And more...

## Methodology

### Build Configuration

All experiments use consistent build settings:
- **Java Version**: 21 (for consistency)
- **Direct Linking**: Enabled (default in pom.xml)
- **Maven Profile**: `local` (includes all dependencies)
- **Build Command**: `mvn clean package -Plocal -Dmaven.test.skip=true`

### Metrics Measured

1. **Primary Metric**: Uberjar size (bytes)
   - Baseline: Built from master branch
   - Optimized: Built from experiment branch
   - Difference: baseline_size - optimized_size

2. **Secondary Metrics** (when applicable):
   - Bytecode instruction count differences
   - Class file count differences
   - Specific bytecode pattern changes

### Reproducibility

Each experiment is designed to be 100% reproducible:
- Deterministic builds using fixed Java version
- Automated scripts with no manual steps
- CI verification on every run
- Results checked into repository

## Interpreting Results

### Size Reduction

- **Positive** (baseline > optimized): Optimization reduces bytecode
- **Negative** (baseline < optimized): Optimization adds overhead
- **Zero**: No measurable impact on final JAR size

### Statistical Significance

Given the large size of the Clojure uberjar (~4MB), we consider:
- **> 1000 bytes**: Clearly measurable impact
- **100-1000 bytes**: Small but meaningful impact
- **< 100 bytes**: Marginal impact, may be noise

### Bytecode Analysis

For experiments with clear size impacts, we extract and compare:
- Representative class files that use the optimized construct
- Bytecode instruction sequences (via `javap -c`)
- Specific patterns that changed

## Contributing

When adding new experiments:

1. Create a new script: `##-description.sh`
2. Follow the existing script structure
3. Create a corresponding GitHub Actions workflow
4. Update this README with experiment details
5. Run locally first to verify
6. Commit the script (but not the results directory initially)

## Questions & Discussion

For questions about these experiments or suggestions for additional measurements, please see the PR discussion.
