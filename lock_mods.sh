#!/usr/bin/env bash

if [[ -z "$CFCORE_API_TOKEN" ]]; then
	printf '%s\n' 'Please set $CFCORE_API_TOKEN (https://console.curseforge.com/#/api-keys)'
	exit 1
fi

curl 'https://api.curseforge.com/v1/mods/files' \
	--header "X-Api-Key: $CFCORE_API_TOKEN" \
	--header 'Content-Type: application/json' \
	--data "$(jq -n '{"fileIds": [inputs.files[].fileID]}' "$MONIFACTORY_SRC/manifest.json" ./manifest_extras.json)" \
	| jq '.data | unique | sort_by(.modId) | map(.downloadUrl = (.downloadUrl // "https://edge.forgecdn.net/files/\(.id / 1000 | trunc)/\(.id % 1000)/\(.fileName)"))' \
	> mods.json
