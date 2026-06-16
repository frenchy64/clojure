#!/usr/bin/env bash

set -e

rm -rf original
rm -rf rebuild

mvn clean
mvn package -Dmaven.test.skip=true
mv target/ original

mvn clean
mvn package -Dmaven.test.skip=true
mv target/ rebuild

CLASSIFIER=""
#CLASSIFIER="-slim"

pushd original
unzip clojure-1.12.5$CLASSIFIER.jar -d clojure-1.12.5$CLASSIFIER
popd
pushd rebuild
unzip clojure-1.12.5$CLASSIFIER.jar -d clojure-1.12.5$CLASSIFIER
popd
# raw bytecode diff (procyon not on PATH, defaults to bytecode)
diffoscope original/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class rebuild/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class > var.class.raw.diff
# decompiled
PATH="$PATH:bin" diffoscope original/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class rebuild/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class > var.class.diff
javap -c original/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class > original/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class.javap
javap -c rebuild/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class > rebuild/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class.javap
diffoscope original/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class.javap rebuild/clojure-1.12.5$CLASSIFIER/clojure/lang/Var.class.javap > var.javap.diff
