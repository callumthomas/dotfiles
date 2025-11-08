#!/bin/bash

# source $(echo $0 | sed -E 's/\/[^\/]*$//')/../.env
source "${BASH_SOURCE[0]%/*}/../.env"

curl -X POST \
  -H "Authorization: Bearer $HOMEASSISTANT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\": \"light.cals_office_lamp\"}" \
  http://192.168.1.3:8123/api/services/light/toggle
