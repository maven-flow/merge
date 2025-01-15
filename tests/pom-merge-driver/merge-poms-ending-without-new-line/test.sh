#!/bin/bash

set -e

# switch to local working directory
cd "$(dirname "$0")"

../../../pom-merge-driver.sh our-pom.xml base-pom.xml their-pom.xml

diff our-pom.xml expected-our-pom.xml
