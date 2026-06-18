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
unzip -l clojure-1.12.5.jar > clojure-1.12.5.list
unzip clojure-1.12.5.jar -d clojure-1.12.5
popd
pushd rebuild
unzip -l clojure-1.12.5.jar > clojure-1.12.5.list
unzip clojure-1.12.5.jar -d clojure-1.12.5
popd
diffoscope original/clojure-1.12.5.list rebuild/clojure-1.12.5.list > jar-listing.diff
# raw bytecode diff (procyon not on PATH, defaults to bytecode)
diffoscope original/clojure-1.12.5/clojure/lang/Var.class rebuild/clojure-1.12.5/clojure/lang/Var.class > var.class.raw.diff
# decompiled
PATH="$PATH:bin" diffoscope original/clojure-1.12.5/clojure/lang/Var.class rebuild/clojure-1.12.5/clojure/lang/Var.class > var.class.procyon.diff
javap -c original/clojure-1.12.5/clojure/lang/Var.class > original/clojure-1.12.5/clojure/lang/Var.class.javap
javap -c rebuild/clojure-1.12.5/clojure/lang/Var.class > rebuild/clojure-1.12.5/clojure/lang/Var.class.javap
diffoscope original/clojure-1.12.5/clojure/lang/Var.class.javap rebuild/clojure-1.12.5/clojure/lang/Var.class.javap > var.javap.diff

# raw bytecode diff (procyon not on PATH, defaults to bytecode)
diffoscope original/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class rebuild/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class > invoke_tool.raw.diff
# decompiled
PATH="$PATH:bin" diffoscope original/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class rebuild/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class > invoke_tool.procyon.diff
javap -c original/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class > original/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class.javap
javap -c rebuild/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class > rebuild/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class.javap
diffoscope original/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class.javap rebuild/clojure-1.12.5/clojure/tools/deps/interop\$invoke_tool.class.javap > invoke_tool.javap.diff
