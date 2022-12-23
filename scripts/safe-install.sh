#!/bin/bash
echo The plugin is located in: \"$HELM_PLUGIN_DIR\" and its name is: \"$HELM_PLUGIN_NAME\"
OUTPUT_TEMP="$(mktemp)"
PREFLT_MANIFEST="$(mktemp)"
${HELM_BIN} template "$@" --set-string generatePreflights=true | yq e '. | select(.kind == "Preflight")' > ${PREFLT_MANIFEST}

k() {
    kubectl -n "${HELM_NAMESPACE}" "$@"
}

if [[ "${PREFLIGHT_PRINT_ONLY}" == "true" ]]; then
    echo "Printing preflight manifest"
    cat "${PREFLT_MANIFEST}"
    exit 0
fi

# Run Local Method
if [[ "${PREFLIGHTS_LOCAL}" == "true" ]]; then
    echo "Running preflights locally"
    k preflight --interactive=false --format json "${PREFLT_MANIFEST}"
else
    k create configmap preflight-config --from-file="${PREFLT_MANIFEST}"
    # timeout is set long to allow for things like autopilot
    k run --pod-running-timeout=5m --image=replicated/preflight:latest -q --rm -i --restart=Never --attach preflight --override-type json --overrides "$(cat $HELM_PLUGIN_DIR/scripts/preflight-pod-override.json)" -- \
            preflight --interactive=false --format json /preflights/$(basename "${PREFLT_MANIFEST}")
    k delete configmap preflight-config
fi


echo "Based on the above results, would you like to continue? [y/N]: "
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
    echo "Continuing with Helm install"
    ${HELM_BIN} install "$@"
else
    echo "Exiting"
    exit 1
fi

#

