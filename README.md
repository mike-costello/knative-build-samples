
# Knative Build Samples for that Special Cloud Native Build in Your Life

## Install Knative with Minishift

Follow instructions here:
https://github.com/knative/docs/blob/master/docs/install/Knative-with-Minishift.md

Notes on automated installer:

- set `OPENSHIFT_VERSION` to v3.11.43 in `install-on-minishift.sh`
- set `minishift config set skip-check-openshift-release true` to workaround CDK v3.7 [bug](https://access.redhat.com/documentation/en-us/red_hat_container_development_kit/3.7/html/release_notes_and_known_issues/known_issues)

## Deploy a sample Fuse build template

Create a secret to store credentials to the destination image registry.

For example:

```
oc create secret docker-registry quay --docker-server=quay.io --docker-username=<username> --docker-password=<password>
```

Apply the build template.

```
oc apply -f build/java8-buildah-template.yaml
```

Start a build.

```
oc apply -f build/camel-simple-build.yaml
```
