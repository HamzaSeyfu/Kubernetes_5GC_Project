#!/bin/bash

echo "Deploiement of the 5GC dans Kubernetes..."

# Make the namespace s’il n’existe pas déjà
kubectl get ns 5gc >/dev/null 2>&1 || kubectl create namespace 5gc

# Apply les YAMLs of deploiement
kubectl apply -f namespace.yaml
kubectl apply -f amf-deployment.yaml
kubectl apply -f smf-deployment.yaml
kubectl apply -f upf-deployment.yaml

# Appliquer les services (if not separated)
kubectl apply -f amf-service.yaml
kubectl apply -f smf-service.yaml
kubectl apply -f upf-service.yaml

echo "Deploiement succesful. Vérifie the pods with : kubectl get pods -n 5gc"
