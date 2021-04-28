#/bin/bash

#######################################################################################
# Run an API Gateway on HTTP port 8100 on a local Macbook with the phantom token plugin
#######################################################################################

mkdir -p "$(PWD)/logs"
kong stop 2>/dev/null
export KONG_DATABASE='off' \
       KONG_DECLARATIVE_CONFIG="$(PWD)/kong.yml" \
       KONG_PROXY_LISTEN='0.0.0.0:8100 reuseport backlog=16384' \
       KONG_LUA_PACKAGE_PATH="/usr/local/Cellar/openresty@1.17.8.2/1.17.8.2/luarocks/share/lua/5.1/?.lua" \
       KONG_PLUGINS="bundled,phantom-token" \
       KONG_LOG_LEVEL="info" \
       KONG_PROXY_ACCESS_LOG="$(PWD)/logs/access.log" \
       KONG_PROXY_ERROR_LOG="$(PWD)/logs/error.log" \
       && kong start -v
if [ $? -ne 0 ]
then
  echo "Problem encountered starting Kong"
  exit 1
fi

#
# Now run this command to see a 401 access denied returned by the gateway
# Then view logs/error.log for details of the failure
# - curl -H "Authorization: Bearer XXX" http://localhost:8100/api