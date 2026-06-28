#!/usr/bin/env bash

set -e

mvn --batch-mode --no-transfer-progress clean install -Dmaven.test.skip=true
# expected to fail
mvn --batch-mode --no-transfer-progress clean verify artifact:compare -Dmaven.test.skip=true -PoptimizeSyntaxQuote || true

cat target/clojure-1.13.0-syntaxquotedvec.buildcompare
diffoscope target/reference/org.clojure/clojure-1.13.0-syntaxquotedvec.jar target/clojure-1.13.0-syntaxquotedvec.jar > clojure-1.13.0-syntax-quotedvec.jar.diffoscope

cat clojure-1.13.0-syntax-quotedvec.jar.diffoscope
