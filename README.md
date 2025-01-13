# Maven Flow Merge

A GitHub action for merging Maven projects developed according to [GIT Flow](https://nvie.com/posts/a-successful-git-branching-model/). It's aim is to automatically resolve GIT merge conflicts in changelog files and Maven project files (`pom.xml`) which arise when using this approach.

## The Problem With Merging Changelogs And POM Files

Let's imagine a model situation:

- You have a Maven project which uses GIT Flow.

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

- A comprehensive description of how the changelog files are actually merged can be found in the [merge driver description](https://github.com/maven-flow/changelog-merge-driver?tab=readme-ov-file#how-it-works-normal-mode).

## How POM Files Are Merged

This action also uses a special GIT merge driver for Maven project files (`pom.xml`).

If a version conflict is detected, the version in `ours` is temporarily changed to the version from`theirs`, and a standard GIT merge is performed by calling `git merge-file`. After the merge, the version in `ours` is changed back into the original value.

It is essentially the same as in this [stackoverflow answer](https://stackoverflow.com/a/33181239/2468620), except that no additional commits are made. The GIT history will remain clean and contain only the merge commit.

NOTE: There can still be conflicts in other parts of the `pom.xml` file.

This merge driver works also for multi-module Maven projects, even in cases when the project version is inherited from the parent project version.

## Usage

Preconditions:

- The GIT repository needs to be checked-out with full history, otherwise you will get an "unrelated histories" error message upon merge. To checkout the full history, call action `actions/checkout` with attribute `fetch-depth: 0`. See example workflow below.

- The `GITHUB_TOKEN` (which is used by default in `actions/checkout`) needs to have write permission for scope `contents`, otherwise the merge cannot be pushed.
  See [GitHub documentation](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token) and example workflow below.

- To merge POM files, the merge job needs run on a Linux-based runner (the pom merge driver is a bash script).

- To merge changelogs, the merge job needs to set up Java 17 or later (the changelog merge driver runs on Java).

Minimum action configuration (merge from current branch into `develop`):

```yaml
    - name: Merge into develop
      uses: maven-flow/merge@v1
      with:
        source-branch: ${{ github.ref_name }}
        target-branch: 'develop'
```

Full action configuration:

```yaml
    - name: Merge into develop
      uses: maven-flow/merge@v1
      with:
        changelog-file: '**/CHANGELOG.md'
        changelog-rebase: false
        pom-file: '**/pom.xml'
        push-changes: true
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
    permissions:
      contents: write                   # write permission needed to enable GIT push after merge
    steps:

    - uses: actions/checkout@v4
      with:
        fetch-depth: 0                  # the full GIT history needs to be checked out

    - name: Set up JDK 17               # Java >= 17 is needed to run the changelog merge driver
      uses: actions/setup-java@v4
      with:
        java-version: '17'
        distribution: 'temurin'

    - name: Merge to develop branch
      uses: maven-flow/merge@v1
      with:
        source-branch: ${{ github.ref_name }}
        target-branch: 'develop'
```

## Inputs

### `changelog-file`

**Optional.** The name of your changelog file. It may contain wildcard characters - the same format as in `.gitignore` or `.gitattributes` files.

**Default value:** `**/CHANGELOG.md`

### `changelog-rebase`

**Optional.** Whether or not the changelog merge driver should run in [rebase mode](https://github.com/maven-flow/changelog-merge-driver/tree/main?tab=readme-ov-file#how-it-works-rebase-mode). Recommended setting is `false` for merging feature branches into `develop`, and `true` when updating feature branches with latest changes from `develop`.

**Default value:** `false`

### `pom-file`

**Optional.** The name of your Maven project files. It may contain wildcard characters - the same format as in `.gitignore` or `.gitattributes` files. In multi-module Maven projects it is recommended to use wildcards to match project files of the parent project and all of it's sub-modules.

**Default value:** `**/pom.xml`

### `push-changes`

**Optional.** Whether the merge should be pushed.

**Default value:** `true`

### `source-branch`

**Required.** The name of the source branch - the branch FROM which the changes will be merged.

### `target-branch`

**Required.** The name of the target branch - the branch INTO which the changes will be merged.

## Disabling Custom Merge Drivers

If you want to disable custom merge behavior for changelogs or POM files (or both) and perform a standard GIT merge instead, simply set the value of attribute `changelog-file` or `pom-file` to something that will not match any existing file in your repository.

For example:

```yaml
    - name: Merge into develop
      uses: maven-flow/merge@v1
      with:
        changelog-file: 'match-nothing.txt'    # turn off custom merging for changelogs
        pom-file: 'match-nothing.txt'          # turn off custom merging for POM files
        source-branch: ${{ github.ref_name }}
        target-branch: 'develop'
```
