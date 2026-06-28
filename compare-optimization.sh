#!/usr/bin/env bash

set -e

mvn clean install -Dmaven.test.skip=true -DargLine="-Dclojure.disable-splice-optimization=y"
mvn clean verify artifact:compare -Dmaven.test.skip=true 

cat target/clojure-1.13.0-syntaxquotedvec.buildcompare
diffoscope target/reference/org.clojure/clojure-1.13.0-syntaxquotedvec.jar target/clojure-1.13.0-syntaxquotedvec.jar
