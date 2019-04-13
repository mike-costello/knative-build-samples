#!/bin/bash -x

#Build OCI image from Fuse Dockerfile 
buildah bud -t $POD_NAMESPACE/$IMAGE_NAME .
#Push the OCI Image to the local Docker registry 
buildah push --tls-verify=false \
  --creds=openshift:$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) \
   $POD_NAMESPACE/$IMAGE_NAME \
   docker://docker-registry.default.svc:5000/$POD_NAMESPACE/$IMAGE_NAME