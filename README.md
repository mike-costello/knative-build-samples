
# Knative Build Samples for that Special Cloud Native Build in Your Life

## Install Knative with Minishift

Follow instructions here:
https://github.com/knative/docs/blob/master/docs/install/Knative-with-Minishift.md

Notes on automated installer:

- set `OPENSHIFT_VERSION` to v3.11.43 in `install-on-minishift.sh`
- set `minishift config set skip-check-openshift-release true` to workaround CDK v3.7 [bug](https://access.redhat.com/documentation/en-us/red_hat_container_development_kit/3.7/html/release_notes_and_known_issues/known_issues)

## Deploy a sample Fuse build template

The Knative build template specifies a destination repository where images will be published. The build template will usually provide or reference credentials for access to the destination repository.

### Integrate with an external registry

To integrate with an external image registry, for example [quay.io](https://quay.io), create a secret to store credentials to access the registry. OpenShift CLI tooling provides a command specifically for storing docker registry credentials as a secret.

```
oc create secret docker-registry <secret-name> --docker-server=<registry-name> --docker-username=<username> --docker-password=<password>
```

For example:

```
oc create secret docker-registry quay --docker-server=quay.io --docker-username=johnnydev --docker-password=tubular
```

The provided build template already references a secret called `quay`. Substitute the secret name in `build/java8-buildah-template.yaml` to the secret name chosen in the previous step if a different name was used.

```
  volumes:
    ...
    - name: registry-credentials
      secret:
        secretName: quay
```

```
oc apply -f build/java8-buildah-template.yaml
```

### Integrate with the internal OpenShift registry

The provided Camel build example specifies that the build pod should run as a service account called `builder`. A `builder` service account is automatically created for each new OpenShift project and has access to a secret that stores its internal registry credentials.

To leverage the `builder` service account's credentials, first find the name of the registry secret.

```
$ oc describe sa builder
Name:                builder
Namespace:           myproject
Labels:              <none>
Annotations:         <none>
Image pull secrets:  builder-dockercfg-g88mm
Mountable secrets:   builder-token-4dw79
                     builder-dockercfg-g88mm
Tokens:              builder-token-4dw79
                     builder-token-mlts7
Events:              <none>
```

In this example, the secret named `builder-dockercfg-g88mm` is the secret that stores credentials to the internal registry.

Change the secret name in the volume called `registry-credentials` in the build template to the secret name determined during the previous step, in the example, the value is changed to `builder-dockercfg-g88mm`.

```
  volumes:
    ...
    - name: registry-credentials
      secret:
        secretName: builder-dockercfg-g88mm
```

Modify the `--authfile` flag on the buildah push command in the build template to look for a file called `.dockercfg` as is the convention for the OpenShift docker-registry secret type.

```
  steps:
    ...
    - name: push-image
      image: ${BUILDER_IMAGE}
      args: ["push", "--authfile=/reg/.dockercfg", "--tls-verify=false", "localhost/myproject/${IMAGE_NAME}", "${DESTINATION_REGISTRY}/${IMAGE_NAME}"]
      volumeMounts:
         - name: varlibcontainers
           mountPath: /var/lib/containers
         - name: registry-credentials
           mountPath: /reg
```

Finally, change the default destination registry to the internal registry in the build template.

```
  parameters:
    ...
    - name: DESTINATION_REGISTRY
      description: The registry where resulting image is pushed
      default: docker-registry.default.svc:5000/myproject
```


## Start a Knative build

To start a build, use the provided build definition `build/camel-simple-build.yaml`.

Customize the arguments in the build.

```
  arguments:
    - name: IMAGE_NAME
      value: "camel-simple:0.0.1"
    - name: CONTEXT_DIR
      value: ""
    - name: JAVA_APP_NAME
      value: "camel-simple.jar"
```

Apply the build definition to start a build pod.

```
oc apply -f build/camel-simple-build.yaml
```
The builder pod will begin executing the build steps as init containers.

```
$ oc get pods
NAME                            READY     STATUS     RESTARTS   AGE
camel-simple-build-pod-326c8a   0/1       Init:1/5   0          5s
```

Follow the logs for any particular step by targeting the init containers by name, for example:

```
$ oc logs camel-simple-build-pod-326c8a -c build-step-build-image --follow
STEP 1: FROM registry.access.redhat.com/fuse7/fuse-java-openshift
Getting image source signatures
Copying blob sha256:c325120ebc8d0e6d056a7b3ca1ba9f5cf9e2d48e6bbca1f9cd8492d7f0674008
Copying blob sha256:c9d123037991e434b21f9721aa46f6808fd4adb212ae3ca1d7263623f645cf2d
Copying blob sha256:0320b66e7e6d94dc462804e870907e8d19581e620861603f94f60da720d78996
Copying blob sha256:bc1b4afc3e2200609be327704ac46aa169d863121310341ba85a90ad0dcf1633
Copying blob sha256:525ed213a38ff917bd2372221b3c595da4c6d62e561ac6f7f6966c2643795d76
Copying config sha256:27492a8ef75b9498fa12ea5befc193e0baf8c4a6776521cd15172d3605eabdce
Writing manifest to image destination
Storing signatures
STEP 2: ENV JAVA_APP_DIR=/deployments
STEP 3: EXPOSE 8080 8778 9779
STEP 4: COPY target/*.jar /deployments/
STEP 5: COMMIT containers-storage:[vfs@/var/lib/containers/storage+/var/run/containers/storage:overlay.mount_program=/usr/bin/fuse-overlayfs,overlay.mountopt=nodev]localhost/myproject/camel-simple:0.0.1
Getting image source signatures
Copying blob sha256:9197342671da8b555f200e47df101da5b7e38f6d9573b10bd3295ca9e5c0ae28
Copying blob sha256:0b7385461a2a5e9d7c164fd983e5f08f96ec5a42e260e5c2818191ac98ee723d
Copying blob sha256:089897f1fd516f5c7b0b6a32114b48cd672791d7913360f44cb42f21dac3ea1b
Copying blob sha256:a57e9947955ce374a406f6a1322f121d6b0debae52f035b3403f0f30f24a1f17
Copying blob sha256:29c7014e33d4b866ec2a924d269d92cb95c2480b5fbfee77a00755aaf80dd814
Copying blob sha256:29da84791fcbac7c3bec9da1618c20b9f1fd93c764d0688b998c873eff1b4426
Copying config sha256:c62bd22bc67e79ec4857dc0aa2469f78039a587d751d8b9f1722eef67d4a45df
Writing manifest to image destination
Storing signatures
```

Once the newly built container image is successfully pushed to the destination registry, the build pod will report a completed status.

```
$ oc get pods
NAME                            READY     STATUS      RESTARTS   AGE
camel-simple-build-pod-326c8a   0/1       Completed   0          5m
```
