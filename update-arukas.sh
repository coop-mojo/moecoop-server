#!/bin/sh

image=$1

app_id=$(curl -Ssn -X GET https://app.arukas.io/api/services | jq -r '.data[0].id')

curl -Ssn -X PATCH -H "Content-Type: application/json" https://app.arukas.io/api/services/$app_id -d "{
  \"data\": {
    \"attributes\": {
      \"image\": \"$image\"
    }
  }
}" > /dev/null
