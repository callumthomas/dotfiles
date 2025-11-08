#!/bin/bash

# source $(echo $0 | sed -E 's/\/[^\/]*$//')/../.env
source "${BASH_SOURCE[0]%/*}/../.env"

VALUE="$1"

if ! [[ "$1" =~ (\+|\-)?[0-9]+$ ]]; then
  echo "invalid input"
  exit 1
fi

get_current_value() {
  local cb=$(curl -X GET \
    -H "Authorization: Bearer $HOMEASSISTANT_TOKEN" \
    -H "Content-Type: application/json" \
    http://192.168.1.3:8123/api/states/light.cals_office_lamp | jq -r '.attributes.brightness')
  echo $cb
  if [[ "$cb" == "null" ]]; then
    echo 0
  else
    echo $brightness
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
  http://192.168.1.3:8123/api/services/light/turn_on
