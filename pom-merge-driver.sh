#!/bin/bash

ours=$1
base=$2
theirs=$3

ourVersion=$(mvn -B help:evaluate -Dexpression=project.version -q -DforceStdout --file ${ours})
echo "Our version: ${ourVersion}"

baseVersion=$(mvn -B help:evaluate -Dexpression=project.version -q -DforceStdout --file ${base})
echo "Base version: ${baseVersion}"

theirVersion=$(mvn -B help:evaluate -Dexpression=project.version -q -DforceStdout --file ${theirs})
echo "Their version: ${theirVersion}"

if [ "$ourVersion" != "$baseVersion" ] && [ "$theirVersion" != "$baseVersion" ] && [ "$ourVersion" != "$theirVersion" ]; then
    echo "Found a version conflict."
    foundVersionConflict=true
    mvn versions:set -DnewVersion=${theirVersion} -DgenerateBackupPoms=false --file ${ours}
else
    echo "No version conflict found."
    foundVersionConflict=false
fi

git merge-file $ours $base $theirs

if [ "$foundVersionConflict" = "true" ]; then
    mvn versions:set -DnewVersion=${ourVersion} -DgenerateBackupPoms=false --file ${ours}
fi
