#!/bin/bash

getVersion() {
	file=$1

	version=$(xmlstarlet sel -t -m _:project -v _:version "${file}")

	if [ -z "$version" ]; then
		version=$(xmlstarlet sel -t -m _:project/_:parent -v _:version "${file}")
	fi

	echo "$version"
}

setVersion() {

	file=$1
	oldVersion=$2
	newVersion=$3

	tempFile=$(mktemp)

	insideDependency=false

	# Loop through each line in the input file
	while IFS= read -r line || [[ -n $line ]]; do

		if [[ $line == *"<dependency>"* ]]; then
			insideDependency=true
		fi

		if [[ $line == *"</dependency>"* ]]; then
			insideDependency=false
		fi

		if [[ $insideDependency == false ]]; then
			# Check if line contains the old version and adjust if necessary
			if [[ $line == *"<version>${oldVersion}</version>"* ]]; then
				# Replace the version
				line=$(echo "$line" | sed "s/<version>${oldVersion}<\/version>/<version>${newVersion}<\/version>/")
			fi
		fi

		# Append the modified line to the output file
		echo "$line" >> $tempFile

	done < $file

	# remove new line from the end of file if the original file didn't have it
	if [[ $(tail -n1 "$file" | wc -l) -eq 0 ]]; then
		truncate -s -1 "$tempFile"
	fi

	mv $tempFile $file
}

# ----------------------- start -----------------------------

echo "Running POM merge driver"

ours=$1
base=$2
theirs=$3

if ! command -v xmlstarlet &> /dev/null; then
    echo "xmlstarlet is not installed. Installing it now..."
    sudo apt -y install xmlstarlet
fi

ourVersion=$(getVersion $ours)
echo "Our version: ${ourVersion}"

baseVersion=$(getVersion $base)
echo "Base version: ${baseVersion}"

theirVersion=$(getVersion $theirs)
echo "Their version: ${theirVersion}"

if [ "$ourVersion" != "$baseVersion" ] && [ "$theirVersion" != "$baseVersion" ] && [ "$ourVersion" != "$theirVersion" ]; then
    echo "Found a version conflict."
    foundVersionConflict=true
    setVersion $ours $ourVersion $theirVersion
else
    echo "No version conflict found."
    foundVersionConflict=false
fi

git merge-file $ours $base $theirs
exitCode=$?

if [ $exitCode -ne 0 ]; then
    echo "Error: Command 'git merge file' failed with exit code $exitCode. Exiting."
    exit 1
fi

if [ "$foundVersionConflict" = "true" ]; then
    setVersion $ours $theirVersion $ourVersion
fi
