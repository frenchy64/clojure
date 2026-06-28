#!/usr/bin/env bash

set -e

mvn --batch-mode --no-transfer-progress clean install -Dmaven.test.skip=true
mvn --batch-mode --no-transfer-progress clean verify artifact:compare -Dmaven.test.skip=true
