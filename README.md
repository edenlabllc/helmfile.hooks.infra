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

## Upgrading EKS cluster

### General EKS upgrade instructions

The list of official [EKS](https://aws.amazon.com/eks/) upgrade instructions is
https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html

> Only self-managed [EKS addons](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html) are used. This means that we install all the AWS-related releases via `Helmfile` like any other release.

In general, the steps are the following (should be executed in the specified order):

1. Make the needed changes to the project repository:
   - Upgrade components in [project.yaml](https://github.com/edenlabllc/rmk/blob/develop/docs/configuration/project-management/preparation-of-project-repository.md#projectyaml).
   - Investigate recent changes in case a chart was upgraded, adjust the release values so a new chart is synced correctly.
     > This might be required in case of any incompatibilities between a release and K8S versions.
   - If required, enable/disable releases in `etc/<scope>/<environment>/releases.yaml`.
   - Run `rmk secret manager generate` and `rmk secret manager encode` to generate new secrets by a template.
     > Environments variables might be required by the `generate` command.
   - Resolve recommended [AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) ID and set in `etc/clusters/aws/<environment>/values/worker-groups.auto.tfvars`.
     > Each K8S version has it own recommended AMI image, see the instructions: https://docs.aws.amazon.com/eks/latest/userguide/retrieve-ami-id.html
   - Set the desired K8S version in `k8s_cluster_version` in `etc/clusters/aws/<environment>/values/variables.auto.tfvars`.
2. Resolve recommended `kube-proxy`, `coredns` versions and set it in `upgrade-nodes.sh`.
   > See the following instructions: \
   > https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html \
   > https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html#coredns-add-on-self-managed-update
3. Sync helm releases for all scopes: `upgrade-releases.sh`
   > In general, the script will only contain `rmk release sync`. However, a more complex set might be included.
4. Upgrade the K8S control plane and the system components (1 K8S version will be upgraded per iteration): `upgrade-cluster.sh`
5. Rolling-update nodes, fix [AZs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for [PVs](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) for each [ASG](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html): `upgrade-nodes.sh`
6. Validate cluster health and perform some end-to-end tests.

### Overview of EKS upgrade scripts

There is a dedicated directory for all the K8S upgrade scripts: `bin/k8s-upgrade/`

The scripts are grouped by a _target_ K8S version, e.g.: `bin/k8s-upgrade/1.27/`

The main script is `upgrade-all.sh`. It is a wrapper around the subscripts, the execution is ordered strictly.

The subscripts are `upgrade-releases.sh`, `upgrade-cluster.sh`, `upgrade-nodes.sh`.

> Other scripts might be implemented and added to `upgrade-all.sh` to handle any non-trivial upgrade steps.

The logic in the scripts is pretty straightforward. Most of the instructions are executed linearly one by one
and can be considered as some kind of one-time "migrations". 

> It is recommended to investigate the scripts logic before applying to a K8S cluster.

#### Requirements

* [RMK](https://github.com/edenlabllc/rmk) >= v0.44.2
* [AWS CLI](https://aws.amazon.com/cli/) >= 2.9
* [eksctl](https://eksctl.io/) >= v0.190.0
* [yq](https://mikefarah.gitbook.io/yq) >= v4.35.2

#### Upgrading EKS from 1.23 to 1.27

The scripts support upgrading K8S from a minimal version of `1.23` to `1.27`.

> The current upgrade covers 4 minor versions, therefore the logic is complex. For the next versions, 
> it might have been simplified greatly, when upgrading to the closest version only, e.g. from `1.27` to `1.28`.

> The scripts should be used as a reference point when implementing other upgrade scripts for future versions.
> They should be idempotent and can be re-executed in case of unexpected errors, e.g. connection timeout/error.
> In case of small and reduced clusters, the scripts should check whether a corresponding release exists before applying the changes.

The list of scripts:
- [upgrade-all.sh](bin/k8s-upgrade/1.27/upgrade-all.sh) - Initialize [RMK](https://github.com/edenlabllc/rmk) configuration, calling rest of scripts one by one (the main upgrade script).
- [upgrade-releases.sh](bin/k8s-upgrade/1.27/upgrade-releases.sh) - Upgrade all releases. The following subscripts are executed:
  - [upgrade-kafka-operator.sh](bin/k8s-upgrade/1.27/upgrade-kafka-operator.sh) - Upgrade the [kafka](https://kafka.apache.org/) [operator](https://strimzi.io/).
  - [upgrade-postgres-operator.sh](bin/k8s-upgrade/1.27/upgrade-postgres-operator.sh) - Upgrade the [postgres](https://www.postgresql.org/) [operator](https://postgres-operator.readthedocs.io/en/latest/).
  - [upgrade-loki-stack.sh](bin/k8s-upgrade/1.27/upgrade-loki-stack.sh) - Upgrade the [loki stack](https://github.com/grafana/helm-charts/tree/main/charts/loki-stack).
  - [upgrade-linkerd-planes.sh](bin/k8s-upgrade/1.27/upgrade-linkerd-planes.sh) - Upgrade [Linkerd](https://linkerd.io/) to the latest version (executes the full `release sync` command multiple times).
    > This is the most complex script, because the Linkerd charts have been reorganized recently and split into multiple ones. 
    > Therefore, the scripts contain some tricky parts, e.g. forcing pod restarts manually. In general, it is needed for some of the releases which freeze during the upgrade at some point.
- [upgrade-cluster.sh](bin/k8s-upgrade/1.27/upgrade-cluster.sh) - Upgrade the K8S control plane and system worker node components (1 K8S version per iteration).
- [upgrade-nodes.sh](bin/k8s-upgrade/1.27/upgrade-nodes.sh) - Rolling-update all the K8S worker nodes.

Before running the scripts you should disable Linkerd in globals **without committing** the changes.
This changes will be reverted automatically in the middle of execution of `upgrade-releases.sh`.

To list all the globals files that should be changed before the execution:

```shell
ls -alh etc/*/<environment>/globals.yaml.gotmpl
```

Current file content:

```yaml
configs:
  # ...
  linkerd:
    # enable/disable linkerd-await at runtime: true|false
    await: true
    # enable/disable linkerd sidecar injection: enabled|disabled
    inject: enabled
  # ...
```

Expected file content before `upgrade-all.sh` is executed:

```yaml
configs:
  # ...
  linkerd:
    # enable/disable linkerd-await at runtime: true|false
    await: false
    # enable/disable linkerd sidecar injection: enabled|disabled
    inject: disabled
  # ...
```

#### Upgrading EKS from 1.27 to 1.29

The scripts support upgrading K8S from a minimal version of `1.27` to `1.29`.

The list of scripts:
- [upgrade-all.sh](bin/k8s-upgrade/1.29/upgrade-all.sh) - Initialize [RMK](https://github.com/edenlabllc/rmk) configuration, calling rest of scripts one by one (the main upgrade script).
- [upgrade-releases.sh](bin/k8s-upgrade/1.29/upgrade-releases.sh) - Upgrade all releases. The following subscripts are executed:
    - [upgrade-ebs-csi-snapshot-scheduler.sh](bin/k8s-upgrade/1.29/upgrade-ebs-csi-snapshot-scheduler.sh) - Upgrade [EBS CSI snapshot scheduler](https://backube.github.io/snapscheduler/) to the latest version.
- [upgrade-cluster.sh](bin/k8s-upgrade/1.29/upgrade-cluster.sh) - Upgrade the K8S control plane and system worker node components (1 K8S version per iteration).
- [upgrade-nodes.sh](bin/k8s-upgrade/1.29/upgrade-nodes.sh) - Rolling-update all the K8S worker nodes.
