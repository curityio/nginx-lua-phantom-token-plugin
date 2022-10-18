FROM kong:3.0.0-alpine

# Deploy the plugin and dependencies for local testing
USER root
COPY ./plugin/*.lua   /tmp/phantom-token/plugin/
COPY ./kong*.rockspec /tmp/phantom-token/
RUN cd /tmp/phantom-token && luarocks make kong-phantom-token-*.rockspec

USER kong