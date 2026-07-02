#!/usr/bin/env bash

mvn clean
mvn -Plocal -Dmaven.test.skip=true package
mkdir -p classes
java -jar clojure.jar -e "(binding [*compiler-options* {:direct-linking true} *compile-files* true] (eval '(defn c1 [] (.cast Object 1))))"
javap -c 'classes/user$c1.class'
