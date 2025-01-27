#!/usr/bin/env bash

if [[ -z "$CFCORE_API_TOKEN" ]]; then
	printf '%s\n' 'Please set $CFCORE_API_TOKEN (https://console.curseforge.com/#/api-keys)'
	exit 1
fi

curl 'https://api.curseforge.com/v1/mods/files' \
	--header "X-Api-Key: $CFCORE_API_TOKEN" \
	--header 'Content-Type: application/json' \
	--data "$(jq '{"fileIds": .files | map(.fileID)}' "$MONIFACTORY_SRC/manifest.json")" \
	| jq '.data | unique | sort_by(.modId) | map(.downloadUrl = ((.id | tostring) as $id | .downloadUrl // "https://edge.forgecdn.net/files/\($id[0:-3])/\($id[-3:] | sub("^0*"; ""))/\(.fileName)"))' \
	> mods.json
