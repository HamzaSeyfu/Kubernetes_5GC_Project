#!/bin/bash

echo "Suppression of the deploiement 5GC..."

kubectl delete -f manifests/upf-service.yaml --ignore-not-found
kubectl delete -f manifests/smf-service.yaml --ignore-not-found
kubectl delete -f manifests/amf-service.yaml --ignore-not-found

kubectl delete -f manifests/upf-deployment.yaml --ignore-not-found
kubectl delete -f manifests/smf-deployment.yaml --ignore-not-found
kubectl delete -f manifests/amf-deployment.yaml --ignore-not-found

kubectl delete -f manifests/namespace.yaml --ignore-not-found

echo "Everything is clean !"
