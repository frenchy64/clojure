#!/usr/bin/env bash

set -e

rm -r target && mvn package -Dmaven.test.skip=true && mv target/ original && mvn package -Dmaven.test.skip=true
pushd original
unzip clojure-1.12.5-slim.jar -d clojure-1.12.5-slim
popd
pushd rebuild
unzip clojure-1.12.5-slim.jar -d clojure-1.12.5-slim
popd
# raw bytecode diff (procyon not on PATH, defaults to bytecode)
diffoscope original/clojure-1.12.5-slim/clojure/lang/Var.class rebuild/clojure-1.12.5-slim/clojure/lang/Var.class > var.class.raw.diff
# decompiled
PATH="$PATH:bin" diffoscope original/clojure-1.12.5-slim/clojure/lang/Var.class rebuild/clojure-1.12.5-slim/clojure/lang/Var.class > var.class.diff
javap -c original/clojure-1.12.5-slim/clojure/lang/Var.class > original/clojure-1.12.5-slim/clojure/lang/Var.class.javap
javap -c rebuild/clojure-1.12.5-slim/clojure/lang/Var.class > rebuild/clojure-1.12.5-slim/clojure/lang/Var.class.javap
diffoscope original/clojure-1.12.5-slim/clojure/lang/Var.class.javap rebuild/clojure-1.12.5-slim/clojure/lang/Var.class.javap > var.javap.diff
