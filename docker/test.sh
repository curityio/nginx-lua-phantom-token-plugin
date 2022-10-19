#!/bin/bash

##################################################################################
# A few sanity tests that can be run in order to test with deployed infrastructure
##################################################################################

API_URL='http://localhost:3000'
RESPONSE_FILE=response.txt

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Ensure that the Curity Identity Server is ready
#
echo 'Waiting for the Curity Identity Server ...'
c=0; while [[ $c -lt 25 && "$(curl -fs -w ''%{http_code}'' localhost:8443)" != "404" ]]; do ((c++)); echo -n "."; sleep 1; done

#
# First authenticate as a client to get an opaque token
#
echo '1. Acting as a client to get an access token ...'
HTTP_STATUS=$(curl -s -X POST http://localhost:8443/oauth/v2/oauth-token \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "client_id=test-client" \
-d "client_secret=secret1" \
-d "grant_type=client_credentials" \
-o $RESPONSE_FILE -w '%{http_code}')    
if [ "$HTTP_STATUS" != '200' ]; then
  echo "*** Problem encountered authenticating as a client, status: $HTTP_STATUS"
  exit 1
fi
OPAQUE_ACCESS_TOKEN=$(cat "$RESPONSE_FILE" | jq -r .access_token)
if [ "$HTTP_STATUS" != '200' ]; then
  echo "*** Unable to get an opaque access token"
  exit 1
fi
echo '1. Successfully authenticated the client and retrieved an access token'

#
# Verify that a client request without an access token fails with a 401
#
echo '2. Testing API request without an access token ...'
HTTP_STATUS=$(curl -i -s -X GET "$API_URL" \
-o $RESPONSE_FILE -w '%{http_code}')
if [ "$HTTP_STATUS" != '401' ]; then
  echo "*** API request without valid access token failed, status: $HTTP_STATUS"
  exit
fi
echo '2. API request received 401 when no valid access token was sent'

#
# Verify that a client request with an invalid access token fails with a 401
#
INVALID_ACCESS_TOKEN='42665300-efe8-419d-be52-07b53e208f46'
echo '3. Testing API request with an invalid access token ...'
HTTP_STATUS=$(curl -i -s -X GET "$API_URL" \
-H "Authorization: Bearer $INVALID_ACCESS_TOKEN" \
-o $RESPONSE_FILE -w '%{http_code}')
if [ "$HTTP_STATUS" != '401' ]; then
  echo "*** API request with invalid access token failed, status: $HTTP_STATUS"
  exit
fi
echo '3. API request received 401 when an invalid access token was sent'

#
# Verify that a client request with a valid access token returns 200
#
echo '4. Testing initial API request with a valid access token ...'
HTTP_STATUS=$(curl -i -s -X GET "$API_URL" \
-H "Authorization: Bearer $OPAQUE_ACCESS_TOKEN" \
-o $RESPONSE_FILE -w '%{http_code}')
if [ "$HTTP_STATUS" != '200' ]; then
  echo "*** API request with a valid access token failed, status: $HTTP_STATUS"
  exit
fi
echo '4. Initial API request received a valid API response'

#
# Verify that a client request with a valid access token returns 200 when served from the cache
#
echo '5. Testing second GET request with a valid access token ...'
HTTP_STATUS=$(curl -i -s -X GET "$API_URL" \
-H "Authorization: Bearer $OPAQUE_ACCESS_TOKEN" \
-o $RESPONSE_FILE -w '%{http_code}')
if [ "$HTTP_STATUS" != '200' ]; then
  echo "*** API request with a valid access token failed, status: $HTTP_STATUS"
  exit
fi
echo '5. Second API request received a valid API response'
