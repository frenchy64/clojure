#!/usr/bin/env bash

set -e

mvn clean install -Dmaven.test.skip=true
mvn clean verify artifact:compare -Dmaven.test.skip=true
