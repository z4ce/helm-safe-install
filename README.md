## Overview

Often it is important to verify that the kubernetes cluster you are deploying a
helm chart into has certain properties. You might need to know that the cluster
is of a certain version to use various APIs. You might need to know that it has
ingress available, a certain amount of ephemeral storage, memory, or CPUs
available. You might want to validate the the service key they provided was
correct or that that database they entered is reachable. Letting a chart deploy
and then finding debugging to see why it failed is a poor user experience.

This helm plugin is designed to solve this and detect issues before helm charts
are deployed by using declarative preflight tests from troubleshoot.sh.

## How it works

The preflight definition yaml are extracted from running `helm template` with
`generatePreflights=true`. The preflights are extracted with `yq`, a ConfigMap
is then created with the contents of the preflight file, which is mounted in a
pod using a container from the troubleshoot project. The preflight tests are
run and the results are presented the user, which then gets a chance to
either continue or halt to correct their configuration.

## Installing

First make sure you have `yq` installed. Then run

```sh
helm plugin install https://github.com/z4ce/helm-safe-install.git
```

## Using

As an end-user you simply run `helm safe-install` in place of `helm install` and
the plugin will take care of verifying your values against the preflight checks
included in the chart.

## Including Preflights in Your Helm Charts

Including preflights in your helm charts is simple. Just follow the instructions
at [troubleshoot.sh](https://troubleshoot.sh/docs/preflight/cluster-checks/) for
syntax on defining your preflight checks. Include the preflight yaml definition
in your helm chart templates folder
and wrap it so that it is only generated when
`generatePreflights=true`.

## Example
The following example shows what a `templates/preflights.yaml` might look like
for the wordpress chart:
```yaml
{{ if eq .Values.generatePreflights "true" }}
apiVersion: troubleshoot.sh/v1beta2
kind: Preflight
metadata:
  name: preflight-tutorial
spec:
  collectors:
    {{ if eq .Values.mariadb.enabled false }}
    - mysql:
        collectorName: mysql
        uri: '{{ .Values.externalDatabase.user }}:{{ .Values.externalDatabase.password }}@tcp({{ .Values.externalDatabase.host }}:{{ .Values.externalDatabase.port }})/{{ .Values.externalDatabase.database }}?tls=false'
    {{ end }}
  analyzers:
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.16.0"
              message: The application requires at least Kubernetes 1.16.0, and recommends 1.18.0.
              uri: https://kubernetes.io
          - warn:
              when: "< 1.18.0"
              message: Your cluster meets the minimum version of Kubernetes, but we recommend you update to 1.18.0 or later.
              uri: https://kubernetes.io
          - pass:
              message: Your cluster meets the recommended and required versions of Kubernetes.
    {{ if eq .Values.mariadb.enabled false }}
    - mysql:
        checkName: Must be MySQL 8.x or later
        collectorName: mysql
        outcomes:
          - fail:
              when: connected == false
              message: Cannot connect to MySQL server
          - fail:
              when: version < 8.x
              message: The MySQL server must be at least version 8
          - pass:
              message: The MySQL server is ready
    {{ end }}
{{ end }}
```