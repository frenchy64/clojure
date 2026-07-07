#!/usr/bin/env bash

set -e

mvn clean -Plocal -Dmaven.test.skip=true package
