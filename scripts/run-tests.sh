#!/usr/bin/env bash
set -euo pipefail

# Namespace and selectors
NS=5gc
LABEL_AMF=app=minimal5gc-minimal5gc-amf
LABEL_SMF=app=minimal5gc-minimal5gc-smf
LABEL_UPF=app=minimal5gc-minimal5gc-upf

echo "Retrieving pod names..."
POD_AMF=$(kubectl get pod -n $NS -l $LABEL_AMF -o jsonpath='{.items[0].metadata.name}')
POD_SMF=$(kubectl get pod -n $NS -l $LABEL_SMF -o jsonpath='{.items[0].metadata.name}')
POD_UPF=$(kubectl get pod -n $NS -l $LABEL_UPF -o jsonpath='{.items[0].metadata.name}')

echo "Pods detected:"
echo "  AMF: $POD_AMF"
echo "  SMF: $POD_SMF"
echo "  UPF: $POD_UPF"
echo

echo "Internal connectivity tests..."
kubectl exec -n $NS $POD_AMF -- sh -c "nc -zv 127.0.0.1 7777 && echo 'AMF: port 7777 OK' || echo 'AMF: port 7777 KO'"
kubectl exec -n $NS $POD_SMF -- sh -c "nc -zv 127.0.0.1 7778 && echo 'SMF: port 7778 OK' || echo 'SMF: port 7778 KO'"
kubectl exec -n $NS $POD_UPF -- sh -c "nc -zv 127.0.0.1 8805 && echo 'UPF: port 8805 OK' || echo 'UPF: port 8805 KO'"
echo

echo "External connectivity tests via services..."
kubectl run -n $NS test-client --rm -i --tty --image=busybox -- sh -c "
  nc -zv minimal5gc-amf 7777 && echo 'Service AMF reachable' || echo 'Service AMF unreachable';
  nc -zv minimal5gc-smf 7778 && echo 'Service SMF reachable' || echo 'Service SMF unreachable';
  nc -zv minimal5gc-upf 8805 && echo 'Service UPF reachable' || echo 'Service UPF unreachable';
"
echo

echo "esilience test: deleting AMF pod..."
kubectl delete pod -n $NS $POD_AMF
echo "Waiting for new AMF pod to be ready..."
kubectl wait --for=condition=Ready pod -l $LABEL_AMF -n $NS --timeout=60s
echo "Re-testing service AMF after failover..."
kubectl run -n $NS test-client2 --rm -i --tty --image=busybox -- sh -c "
  nc -zv minimal5gc-amf 7777 && echo 'AMF OK post-failover' || echo 'AMF KO post-failover';
"
echo

echo "All tests completed !"
