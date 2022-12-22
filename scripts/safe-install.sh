#!/bin/bash
OUTPUT_TEMP=$(mktemp)
kubectl preflight --interactive=false \
                 --format json \
                 --output  "${OUTPUT_TEMP}" \
                  <(helm template "$@" --set-string generatePreflights=true | yq e '. | select(.kind == "Preflight")')

#helm install "$@"
echo The plugin is located in: \"$HELM_PLUGIN_DIR\" and its name is: \"$HELM_PLUGIN_NAME\"
