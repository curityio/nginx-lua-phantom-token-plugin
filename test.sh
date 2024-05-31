
#!/bin/bash

################################################################################################
# After installing these prerequisites, this deploys the latest LUA code and runs all unit tests
# - brew install openresty/brew/openresty
# - cpan Test::Nginx
# - opm install ledgetech/lua-resty-http
# - opm install SkyLothar/lua-resty-jwt
################################################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Point to the OpenResty install
#
OPENRESTY_ROOT=/usr/local/Cellar/openresty/1.25.3.1_1

#
# Ensure that the OpenResty nginx, with LUA support, will be found by the prove tool
#
export PATH=${PATH}:"$OPENRESTY_ROOT/nginx/sbin"

#
# Copy the latest plugin to the LUA libraries folder
#
cp plugin/access.lua "$OPENRESTY_ROOT/lualib/phantom-token.lua"

#
# Deploy the Curity Identity Server and an example API
#
./docker/deploy.sh 'test'
if [ $? -ne 0 ]; then
  echo "Problem encountered deploying the Curity Identity Server"
  exit 1
fi

#
# Run all Perl tests, which will call the Curity Identity Server and the API
#
prove -v -f t/api_requests.t

#
# Free resources
#
./docker/teardown.sh