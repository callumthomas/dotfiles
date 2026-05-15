#!/bin/bash
set -euo pipefail

# source $(echo $0 | sed -E 's/\/[^\/]*$//')/../.env
source "${BASH_SOURCE[0]%/*}/../.env"

VALUE="$1"

if ! [[ "$1" =~ (\+|\-)?[0-9]+$ ]]; then
	echo "invalid input"
	exit 1
fi

if ! ping -c 1 $HOMEASSISTANT_SERVER &>/dev/null; then
	echo "Could not reach server"
	exit 1
fi

get_current_value() {
	local cb
	cb=$(curl -sf -X GET \
		-H "Authorization: Bearer $HOMEASSISTANT_TOKEN" \
		-H "Content-Type: application/json" \
		"http://$HOMEASSISTANT_SERVER:8123/api/states/light.cals_office_lamp" \
		| jq -r '.attributes.brightness')
	if [[ "$cb" == "null" || -z "$cb" ]]; then
		echo 0
	else
		echo "$cb"
	fi
}

if [[ "$VALUE" =~ \+[0-9]+$ ]]; then
	brightness=$(get_current_value)
	echo "current brightness is $brightness"
	VALUE=$(($brightness + ${VALUE:1}))
elif [[ "$VALUE" =~ \-[0-9]+$ ]]; then
	brightness=$(get_current_value)
	echo "current brightness is $brightness"
	VALUE=$(($brightness - ${VALUE:1}))
fi

echo "changing to $VALUE"

curl -X POST \
	-H "Authorization: Bearer $HOMEASSISTANT_TOKEN" \
	-H "Content-Type: application/json" \
	-d "{\"entity_id\": \"light.cals_office_lamp\", \"brightness\": \"$VALUE\"}" \
	http://$HOMEASSISTANT_SERVER:8123/api/services/light/turn_on
