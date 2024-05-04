# Maven Flow Merge

A GitHub action for merging Maven projects developed according to [Maven Flow](https://nvie.com/posts/a-successful-git-branching-model/). It's aim is to automatically resolve GIT merge conflicts in changelog files and Maven project files (`pom.xml`) which arise when using this approach.

## The Problem With Merging Changelogs And POM Files

Let's imagine a model situation:

- You have a Maven project which uses Maven Flow.

- The project has a `develop` branch, which contains version `1.0.0-SNAPSHOT`.

- You create a release branch `release/v1.0.0` from `develop`.

- You bump the version in `develop` to `1.1.0-SNAPSHOT` to add new functionality.

- You add new functionality into `develop` and update the changelog.

- You make some bugfixes in `release/v1.0.0` and update the changelog.

- You release version `1.0.0` from release branch `relase/v1.0.0`.

- Now you need to merge all the changes from `relase/v1.0.0` back into `develop`.

- Since the project version in `develop` has changed from `1.0.0-SNAPSHOT` into `1.1.0-SNAPSHOT`, and the version in `relase/v1.0.0` has changed from `1.0.0-SNAPSHOT` into `1.0.0`, you will get a merge conflict in your `pom.xml` file.

- And since the changelog file in `develop` contains notes about the new functionality, and the changelog file in `release/v1.0.0` contains notes about the bugfixes, you will get a merge conflict in the changelog file as well.

## How Changelogs Are Merged

This action uses a special [GIT merge driver for changelogs](https://github.com/maven-flow/changelog-merge-driver) which parses the changelog files and merges them in a logical way taking into account their structure.

- The changelog file needs to follow the structure defined in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

- A comprehensive description of how the changelog files are actually merged can be found in the [merge driver description](https://github.com/maven-flow/changelog-merge-driver?tab=readme-ov-file#how-it-works).

## How POM Files Are Merged

This action also uses a special GIT merge driver for Maven project files (`pom.xml`).

If a version conflict is detected, the version in `ours` is temporarily changed to the version from`theirs`, and a standard GIT merge is performed by calling `git merge-file`. After the merge, the version in `ours` is changed back into the original value.

It is essentially the same as in this [stackoverflow answer](https://stackoverflow.com/a/33181239/2468620), except that no additional commits are made. The GIT history will remain clean and contain only the merge commit.

NOTE: There can still be conflicts in other parts of the `pom.xml` file.

This merge driver works also for multi-module Maven projects, even in cases when the project version is inherited from the parent project version.

## Usage

Minimum configuration (merge from current branch into `develop`):

```yaml
    - name: Merge into develop
      uses: maven-flow/merge@v1
      with:
        source-branch: ${{ github.ref_name }}
        target-branch: 'develop'
```

Full configuration:

```yaml
    - name: Merge into develop
      uses: maven-flow/merge@v1
      with:
        changelog-file: '**/CHANGELOG.md'
        pom-file: '**/pom.xml'
        source-branch: ${{ github.ref_name }}
        target-branch: 'develop'
```

Example merge workflow:

```yaml
name: Merge to develop

on: push

jobs:

  merge-to-develop:
    if: startsWith(github.ref, 'refs/heads/release') # only run merge on release branches
    runs-on: ubuntu-latest
    steps:

    - uses: actions/checkout@v3
      with:
        fetch-depth: 0                  # the full GIT history needs to be checked out
        token: ${{ github.token }}      # token needed to enable GIT push after merge

    - name: Set up JDK 17               # Java 17 is needed to run the changelog merge driver
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'

    - name: Merge to develop branch
      uses: maven-flow/merge@v1
      with:
        source-branch: ${{ github.ref_name }}
        target-branch: ${{ inputs.upstreamBranch }}
```
