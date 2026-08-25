FROM apache/apisix:3.14.0-debian

USER root
COPY ./plugin/*.lua /usr/local/apisix/apisix/plugins/phantom-token/

#
# APISIX expects to load the plugin from the below path, so add a shim that points to out preferred entry point
#
RUN printf '%s\n' \
    'return require("apisix.plugins.phantom-token.apisix")' \
    > /usr/local/apisix/apisix/plugins/phantom-token.lua

#
# Using plugins: in config.yaml impacts built-in plugins, so add the plugin to the core configuration
#
RUN sed -i '/"fault-injection"/a\    "phantom-token",' \
    /usr/local/apisix/apisix/cli/config.lua

USER apisix
