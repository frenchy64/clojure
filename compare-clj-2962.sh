#!/usr/bin/env bash
# Assumes patch for CLJ-2962 has been applied.
# Compares the compilation of clojure.test-clojure.compilation.syntax-quote/syntax-quoted-vector
# with and without the patch

set -e

PREVIOUS_COMMIT='1c9fb16f6485d5c908b51158115e132beac9339e'
CLASSFILE='target/test-classes/clojure/test_clojure/compilation/syntax_quote$syntax_quoted_vector.class'

mvn clean package
javap -c "$CLASSFILE" > after-syntax-quoted-vector.decomp

git checkout "$PREVIOUS_COMMIT" -- src/jvm/clojure/lang/LispReader.java
mvn clean package || true # will fail
javap -c "$CLASSFILE" > before-syntax-quoted-vector.decomp

git checkout HEAD -- src/jvm/clojure/lang/LispReader.java
