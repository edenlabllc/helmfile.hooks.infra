# helmfile.hooks.infra

[![Release](https://img.shields.io/github/v/release/edenlabllc/helmfile.hooks.infra.svg?style=for-the-badge)](https://github.com/edenlabllc/helmfile.hooks.infra/releases/latest)
[![Software License](https://img.shields.io/github/license/edenlabllc/helmfile.hooks.infra.svg?style=for-the-badge)](LICENSE)
[![Powered By: Edenlab](https://img.shields.io/badge/powered%20by-edenlab-8A2BE2.svg?style=for-the-badge)](https://edenlab.io)

This repository provides shell scripts for the [Helmfile hooks](https://helmfile.readthedocs.io/en/latest/#hooks).
Mainly it is designed to be managed by administrators, DevOps engineers, SREs.

## Contents

* [Requirements](#requirements)
* [Git workflow](#git-workflow)
* [Additional information](#additional-information)
* [Development](#development)
    * [Guidelines](#guidelines)

## Requirements

`helm`, `kubectl`, `yq` = version are specified in
the [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml)
file
of each project of the repository in the `tools` section.

## Git workflow

This repository uses the classic [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
workflow,
embracing all its advantages and disadvantages.

**Stable branches:** develop, master

Each merge into the master branch adds a new [SemVer2](https://semver.org/) tag and a GitHub release is created.

## Additional information

* This set of hook scripts can only be launched from the project repository
  via [RMK](https://github.com/edenlabllc/rmk),
  because the entire input set of the variables is formed by [RMK](https://github.com/edenlabllc/rmk) at the moment the
  release commands are launched, e.g.:

  ```shell
  rmk release sync
  ```

  [RMK](https://github.com/edenlabllc/rmk) also keeps track of which version of the release hook scripts the project
  repository will use.
  The version of the hook scripts artifact is described in
  the [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml)
  file
  of each project repository in the `inventory.hooks` section, e.g.:

   ```yaml
   inventory:
     # ...
     hooks:
       helmfile.hooks.infra:
         version: <SemVer2>
         url: git::https://github.com/edenlabllc/{{.Name}}.git?ref={{.Version}}
     # ...
   ```
* The hook scripts are designed to ensure consistent deployment of Helm releases described in a Helmfile.
  These scripts should be designed with declarative deployment in mind.
  They will only execute when there are differences in the state.

## Development

For development, navigate to the local `.PROJECT/inventory/hooks/helmfile.hooks.infra-<version>/bin` directory of a
project repository,
then perform the changes directly in the files and test them. Finally, copy the changed files to a new feature branch
of this repository and create a pull request (PR).

### Guidelines

This section defines the standards and best practices for developing hook scripts in this repository. All scripts must
adhere to these guidelines to ensure consistency, maintainability, and reliability.

#### Script Structure

1. **Shebang and Error Handling**
    - Line 1: Must contain `#!/usr/bin/env bash`
    - Line 2: Must be blank
    - Line 3: Must contain `set -e` to exit immediately if a command exits with a non-zero status
    - No duplicate `set -e` statements elsewhere in the script

2. **Indentation**
    - Use exactly 2 spaces for indentation throughout all bash code
    - Do not use tabs

#### Variable Declarations and Usage

3. **Quoting Variables**
    - All variable assignments must use quotes: `VAR="${value}"`
    - All variable expansions must use quotes: `"${VAR}"`
    - Command substitutions must be quoted: `VAR="$(command)"`
    - Exception: Arithmetic expansion does not require quotes: `$(( EXPR ))` or `(( EXPR ))`

4. **Variable Naming**
    - Avoid unnecessary prefixes (e.g., `K8S_`, `MONGODB_`, `PG_`)
    - Use descriptive, clear names without redundant prefixes

5. **Readonly Variables**
    - Declare variables as `readonly` if they are assigned once and never modified
    - Apply `readonly` to initial argument assignments: `readonly NAMESPACE="${1}"`
    - Apply `readonly` to constants and configuration values
    - Default argument values are compatible with `readonly`: `readonly LIMIT="${3:-180}"`

6. **Local Variables**
    - Declare variables as `local` within functions to prevent global scope pollution
    - Prefer combining `local` declaration with assignment: `local COUNT=0`
    - All function-scoped variables must be declared as `local`

#### Arithmetic Operations

7. **Arithmetic Formatting**
    - Use spaces around operators in arithmetic expressions: `(( COUNT > LIMIT ))`
    - Use spaces around equality comparisons: `(( COUNT == 0 ))`
    - Use spaces in arithmetic expansion: `$(( SA_DATE - POD_DATE ))`
    - Increment operations: `(( ++COUNT ))` (pre-increment with spaces)
    - Comparison operators: `(( COUNT <= LIMIT ))`, `(( COUNT >= LIMIT ))`

#### Arrays

8. **Array Usage**
    - Iterate arrays using `"${ARRAY[@]}"`: `for ITEM in "${ARRAY[@]}"; do`
    - Array slicing: `("${ARRAY[@]:start}")` to maintain array structure
    - Creating arrays from command output: Use `while IFS= read -r` loop with here-document for POSIX compatibility:
      ```bash
      ARRAY=()
      while IFS= read -r ITEM; do
        if [[ -n "${ITEM}" ]]; then
          ARRAY+=("${ITEM}")
        fi
      done <<EOF
      ${COMMAND_OUTPUT}
      EOF
      ```
    - Avoid `mapfile` for compatibility with older Bash versions or restricted shell environments

#### Tool Preferences

9. **YAML/JSON Processing**
    - Prefer `yq` for most YAML/JSON processing tasks
    - Exception: Golang templates (`go-template`) are currently used in some ready hooks, but may be migrated to `yq` in
      the future for unification
    - Avoid low-level Linux utilities (`sed`, `awk`, `grep`) unless:
        - The output is plain text (not YAML/JSON)
        - `yq` cannot handle the specific use case

#### Argument Order

9. **Standard Argument Order**
    - First argument: `NAMESPACE` (required, no default value)
    - Second argument: `RELEASE_NAME` or `CLUSTER_NAME` (required, no default value)
    - Subsequent arguments: Other parameters as needed
    - Last argument: `LIMIT` (if present, must be the final positional argument)
    - Boolean/enable flags (if present) should come last with default values: `ENABLE_HOOK="${4:-true}"`

10. **Argument Naming**
    - Use `RELEASE_NAME` for Helm release names
    - Use `CLUSTER_NAME` only when referring to a Kubernetes cluster resource (e.g., PostgreSQL cluster)
    - Use `CLUSTER_NAMESPACE` when the cluster resource exists in a different namespace

#### Exit Codes

12. **Exit Code Standards**
    - Use `exit 0` for successful completion
    - Use `exit 1` for errors and failures
    - Ensure all code paths have explicit exit codes

#### Error Messages

13. **Error Message Format**
    - Include script name in error messages: `$(basename "${0}"): Wait timeout exceeded.`
    - Use descriptive error messages that explain what failed
    - Send error messages to stderr: `>&2 echo "ERROR: message"`

#### Control Flow

14. **Loop Usage**
    - Prefer `for` loops for counting iterations: `for (( COUNT=0; COUNT < LIMIT; ++COUNT )); do`
    - Use `while true` loops for polling/waiting scenarios: `while true; do ... done`
    - Convert counting `while` loops to `for` loops where appropriate

#### Hook Naming Convention

15. **Naming Pattern**
    - Format: `<event>-<action>.sh` or `<event>-<event>-<action>.sh` for multiple events
    - Supported events (for the full list,
      see [Helmfile hooks documentation](https://helmfile.readthedocs.io/en/latest/#hooks)):
        - `presync`: Execute before Helm sync operation
        - `postsync`: Execute after Helm sync operation
        - `preuninstall`: Execute before Helm uninstall operation
        - `postuninstall`: Execute after Helm uninstall operation
    - Multiple events: When a hook is used for multiple events, list them explicitly following the order above:
      `<event1>-<event2>-<action>.sh` (e.g., `preuninstall-postuninstall-delete-cluster.sh`)
    - Action: Descriptive verb optionally followed by resource or purpose (e.g., `wait-postgres-ready`,
      `create-postgres-user`, `delete-failed-job`, `restart-airbyte-worker`)
    - Backward compatibility: If a new event is needed for an existing hook, create a new hook file to maintain backward
      compatibility
    - Examples:
        - `presync-create-postgres-user.sh`
        - `postsync-wait-postgres-ready.sh`
        - `preuninstall-postuninstall-delete-cluster.sh`
        - `postuninstall-wait-persistent-volumes-deleted.sh`

#### Function Definitions

16. **Function Best Practices**
    - Use `function` keyword or `function_name()` syntax consistently
    - Declare all function variables as `local`
    - Use descriptive function names that indicate purpose
    - Return explicit exit codes: `return 0` for success, `return 1` for failure

#### Process Substitution

17. **Process Substitution Compatibility**
    - Use here-document with command substitution instead of process substitution (`< <(...)`) for better compatibility:
      ```bash
      OUTPUT="$(command)"
      while IFS= read -r LINE; do
        # process line
      done <<EOF
      ${OUTPUT}
      EOF
      ```
    - This ensures compatibility with restricted shell environments
