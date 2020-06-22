# Simple BOSH network availability checker

This repository is a simple BOSH release that we can use to perform network availability checks from our BOSH subnets. This lets usperiodically validate the network configuration - for example to confirm that we can (or cannot!) access a remote database server from an isolation segment.

A "release" is a set of software and packages that can be installed onto a BOSH-managed VM. You do this in three steps:

1. Compile and upload the release to the BOSH director
2. Upload a stemcell for the VM that you wish to create
3. Create and deploy a BOSH deployment manifest, which will create the VM with the release on it

## Useful internet resources

[How to Create a Lean BOSH Release](https://www.cloudfoundry.org/blog/create-lean-bosh-release/) is an excellent primer into building and extending a simple "hello-world" BOSH release.

For in-depth reference materials, start with [Creating a Release](https://bosh.io/docs/create-release/) in the BOSH documentation.

## Compiling and uploading the release

To rebuild the release:

```sh
bosh create-release --force
```

To upload the release:

```sh
bosh upload-release
```

You can verify that the release is now available on the BOSH director by running `bosh releases`. The release is now in the BOSH blob store. In order to create a VM with the release on it, we need a stemcell and a deployment manifest. Please note that we're not currently storing the release versioning. If you want consistent release versions across the env, you will need to read about "final" releases.

## Uploading a stemcell

Actually, if you are already in PCF, you can just run `bosh stemcells` to get a list of the available stemcells. This release as it currently stands needs nothing special, so you can choose any stemcell version. There is always a `default` stemcell.

## Creating a BOSH deployment manifest

There is a sample [manifest.yml] in this repository. It's pretty simple:

```yaml
name: net-checks
releases:
- name: net-checks
  version: latest

stemcells:
- alias: default
  os: ubuntu-xenial
  version: latest

update:
  canaries: 1
  max_in_flight: 1
  canary_watch_time: 1000-30000
  update_watch_time: 1000-30000

instance_groups:
- name: netchecker
  azs:
  - z1
  lifecycle: errand
  instances: 1
  vm_type: default
  stemcell: default
  networks:
  - name: default
  jobs:
  - name: check-ports
    release: net-checks
    properties:
      port-check: ((tests))
```

Let's break it down a bit.

```yaml
name: net-checks
releases:
- name: net-checks
  version: latest
```

The `name` matches the BOSH deployment name. It's a belt-and-braces check that we're deploying the correct manifest - you wouldn't want to overwrite your `cf` deployment, would you?!.

The `releases` section lists all of the releases that will be used in this deployment. We're just specifying our own one - `net-checks`.

```yaml
stemcells:
- alias: default
  os: ubuntu-xenial
  version: latest
```

The `stemcells` section lists all stemcells that will be used in this deployment.

```yaml
instance_groups:
- name: netchecker
  azs:
  - z1
  lifecycle: errand
  instances: 1
  vm_type: default
  stemcell: default
  networks:
  - name: default
  jobs:
  - name: check-ports
    release: net-checks
    properties:
      port-check: ((tests))
```

We're going to create one errand VM on each subnet we want to check.

| Setting  | Description                                                                                                                |
|----------|----------------------------------------------------------------------------------------------------------------------------|
| name     | Each VM needs a different name, so perhaps `name: netchecker-iso1`.                                                        |
| vm_type  | This will need to match one of the valid VM types in your BOSH cloud config. You can choose the smallest VM type available |
| stemcell | This should match the stemcell section.                                                                                    |
| azs      | This should match the availability zone names for the network you are deploying to.                                        |
| networks | This should match BOSH cloud config network name for the subnet you are deploying to.                                      |
| jobs     | We talk about that next :)                                                                                                 |

```yaml
  jobs:
  - name: check-ports
    release: net-checks
    properties:
      port-check: ((tests))
```

Our release currently just has code for one job, "check-ports". You can see the code in the [/jobs/check-ports/] folder. It consists of a `run` script, and a configuration template. If you look at the configuration template [/jobs/check-ports/templates/check-ports.cfg.erb], you will see that it just converts the `port-check` properties from YAML to a tab-separated list.

So, to specify extra port checks, you just need to add lines to the `properties.port-check` property. In the included example manifest, this extracted into a vars file `tests.yml`, as an array of:

| Property    | Default    | Description                                                                             |
|-------------|------------|-----------------------------------------------------------------------------------------|
| host        | (required) | The host FQDN or IP address to connect to                                               |
| port        | (required) | The TCP/IP port to connect to                                                           |
| protocol    | tcp        | Internet protocol to choose - tcp or udp, but udp tests always succeed, so don't bother |
| should_fail | false      | Set to true if you expect this endpoint to be unreachable                               |
| description |            | A description of the test to output in the log                                          |


(for example):

```yaml
---
- host: 127.0.0.1
  port: 22
- host: 127.0.0.1
  port: 8899
  should_fail: true
  description: Should not be able to hit this port
```

## Deploying and running

```sh
bosh -d net-checks deploy manifest.yml -l tests.yml
bosh -d net-checks run-errand check-ports
```

## Extending this release for more checks

You are advised to read the handy links at the top of this file to get an understanding of how to create BOSH releases. If you're just creating shell scripts, it's fairly straightforward.

1. Create a new job folder in [/jobs]. Use the check-ports job as a template.
2. The monit file should be blank - we're running the tests just once.
3. The spec file describes which template files should be converted into which real files, and what valid properties can be specified in the manifest.
4. The templates themselves are ERB files, which allows you to interpolate the properties in your manifest into the files themselves. This is how config files are created in the VM..
5. You add a new job to your deployment manifest.
