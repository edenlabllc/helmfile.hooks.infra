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
* [Upgrading EKS cluster](#upgrading-eks-cluster)
  * [General EKS upgrade instructions](#general-eks-upgrade-instructions)
  * [Overview of EKS upgrade scripts](#overview-of-eks-upgrade-scripts)
    * [Upgrading to EKS 1.27](#upgrading-to-eks-127)

## Requirements

`helm`, `kubectl`, `jq`, `yq` = version are specified in the [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml) file
of each project of the repository in the `tools` section.

## Git workflow

This repository uses the classic [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) workflow,
embracing all its advantages and disadvantages.

**Stable branches:** develop, master

Each merge into the master branch adds a new [SemVer2](https://semver.org/) tag and a GitHub release is created.

## Additional information

* This set of hook scripts can only be launched from the project repository via [RMK](https://github.com/edenlabllc/rmk), 
  because the entire input set of the variables is formed by [RMK](https://github.com/edenlabllc/rmk) at the moment the release commands are launched, e.g.:
  
  ```shell
  rmk release sync
  ```
  
  [RMK](https://github.com/edenlabllc/rmk) also keeps track of which version of the release hook scripts the project repository will use. 
  The version of the hook scripts artifact is described in the [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml) file 
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

For development, navigate to the local `.PROJECT/inventory/hooks/helmfile.hooks.infra-<version>/bin` directory of a project repository, 
then perform the changes directly in the files and test them. Finally, copy the changed files to a new feature branch 
of this repository and create a pull request (PR).
