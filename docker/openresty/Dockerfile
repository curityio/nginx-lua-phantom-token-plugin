FROM openresty/openresty:1.31.1.1-bookworm-fat

# Deploy the plugin and dependencies for local testing
COPY ./lua*.rockspec     /tmp/phantom-token/
COPY ./plugin/access.lua /tmp/phantom-token/plugin/
RUN cd /tmp/phantom-token && luarocks make lua-resty-phantom-token-*.rockspec
