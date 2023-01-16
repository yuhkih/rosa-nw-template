#!/bin/bash

# ------------------------------------------------------
# Make sure aws cli is configured properly before run this shell
# ------------------------------------------------------
# History
# 2023/01/16 yuhkih initial creation

# ------------------------------------------------------
# Basic Information
# ------------------------------------------------------
ClusterName=mycluster

# ------------------------------------------------------
# Delete cluster
# ------------------------------------------------------
echo "=============================================================="
echo "[Log] get cluster id"
CLUSTER_ID=$(rosa list cluster | grep $ClusterName | awk -F' ' '{print $1}')
echo "CLUSTER_ID = " $CLUSTER_ID


echo "=============================================================="
echo "[Log] delete cluster"
rosa delete cluster -y -c $ClusterName

echo "=============================================================="
echo "[Log] wait for the completion"
rosa logs uninstall -c $ClusterName --watch



# ------------------------------------------------------
# Delete operator-roles and oidc-provider
# ------------------------------------------------------
echo "=============================================================="
echo "[Log] delete operator-roles"
rosa delete operator-roles -y -m auto -c $CLUSTER_ID
echo "[Log] delete oidc-provider"
rosa delete oidc-provider  -y -m auto -c $CLUSTER_ID