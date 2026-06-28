#!/usr/bin/env bash

set -e

mvn --batch-mode --no-transfer-progress clean install -Dmaven.test.skip=true
# expected to fail
mvn --batch-mode --no-transfer-progress clean verify artifact:compare -Dmaven.test.skip=true -PoptimizeSyntaxQuote || true

cat target/clojure-1.13.0-syntaxquotedvec.buildcompare

# Produce diffoscope of the two jars
diffoscope target/reference/org.clojure/clojure-1.13.0-syntaxquotedvec.jar target/clojure-1.13.0-syntaxquotedvec.jar > clojure-1.13.0-syntax-quotedvec.jar.diffoscope || true
cat clojure-1.13.0-syntax-quotedvec.jar.diffoscope

# Also produce a more detailed diff by unzipping, disassembling .class files with javap, and comparing directories
TMPDIR=$(mktemp -d)
REFDIR="$TMPDIR/ref"
OPTIMDIR="$TMPDIR/opt"
mkdir -p "$REFDIR" "$OPTIMDIR"

unzip -q target/reference/org.clojure/clojure-1.13.0-syntaxquotedvec.jar -d "$REFDIR"
unzip -q target/clojure-1.13.0-syntaxquotedvec.jar -d "$OPTIMDIR"

# Disassemble .class files: replace .class files with javap output files (with .java_disasm suffix)
for DIR in "$REFDIR" "$OPTIMDIR"; do
  find "$DIR" -name '*.class' -print0 | while IFS= read -r -d '' CLASSFILE; do
    # compute class name from file path
    RELPATH="${CLASSFILE#$DIR/}"
    CLASSNAME="${RELPATH%.class}"
    CLASSNAME="${CLASSNAME//\//.}"
    # run javap and write to a .class.disasm file next to original
    javap -c -p -classpath "$DIR" "$CLASSNAME" > "${CLASSFILE}.disasm" 2>/dev/null || javap -c -classpath "$DIR" "$CLASSNAME" > "${CLASSFILE}.disasm" 2>/dev/null || echo "failed to disassemble $CLASSFILE" > "${CLASSFILE}.disasm"
    # remove original .class file
    rm -f "$CLASSFILE"
  done
done

# Now run diffoscope on the two directories
diffoscope "$REFDIR" "$OPTIMDIR" > clojure-1.13.0-syntax-quotedvec.dir.diffoscope || true
cat clojure-1.13.0-syntax-quotedvec.dir.diffoscope

# cleanup
# keep TMPDIR for artifact upload; do not remove immediately so GitHub Actions can access files
echo "Detailed disassembly diff at: $TMPDIR"
