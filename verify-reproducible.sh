#!/usr/bin/env bash

set -e

mvn --batch-mode clean install -Dmaven.test.skip=true
mvn --batch-mode clean verify artifact:compare -Dmaven.test.skip=true
