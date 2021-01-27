#!/bin/sh

# This script is used to start tidb containers in kubernetes cluster
# Use DownwardAPIVolumeFiles to store informations of the cluster:
# https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#the-downward-api
#
#   runmode="normal/debug"
#
set -uo pipefail
ANNOTATIONS="/etc/podinfo/annotations"
if [[ ! -f "${ANNOTATIONS}" ]]
then
    echo "${ANNOTATIONS} does't exist, exiting."
    exit 1
fi
source ${ANNOTATIONS} 2>/dev/null
runmode=${runmode:-normal}
if [[ X${runmode} == Xdebug ]]
then
    echo "entering debug mode."
    tail -f /dev/null
fi
# Use HOSTNAME if POD_NAME is unset for backward compatibility.
POD_NAME=${POD_NAME:-$HOSTNAME}
ARGS="--store=tikv --advertise-address=${POD_NAME}.${HEADLESS_SERVICE_NAME}.${NAMESPACE}.svc --host=0.0.0.0 --path=${CLUSTER_NAME}-pd:2379 --config=/etc/tidb/tidb.toml
"
if [[ X${BINLOG_ENABLED:-} == Xtrue ]]
then
    ARGS="${ARGS} --enable-binlog=true"
fi
SLOW_LOG_FILE=${SLOW_LOG_FILE:-""}
if [[ ! -z "${SLOW_LOG_FILE}" ]]
then
    ARGS="${ARGS} --log-slow-query=${SLOW_LOG_FILE:-}"
fi
echo "start tidb-server ..."
echo "/tidb-server ${ARGS}"
while true; do
    GO_FAILPOINTS="github.com/pingcap/tidb/server/enableTestAPI=return" \
    /tidb-server ${ARGS} 2>&1 | tee -a /var/log/tidb/tidb.log
    sleep 1
done
