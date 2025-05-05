#!/bin/bash

echo "Suppression of the deploiement 5GC..."

kubectl delete -f upf-service.yaml --ignore-not-found
kubectl delete -f smf-service.yaml --ignore-not-found
kubectl delete -f amf-service.yaml --ignore-not-found

kubectl delete -f upf-deployment.yaml --ignore-not-found
kubectl delete -f smf-deployment.yaml --ignore-not-found
kubectl delete -f amf-deployment.yaml --ignore-not-found

kubectl delete -f namespace.yaml --ignore-not-found

echo "Everything is clean !"
