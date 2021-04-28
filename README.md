# Overview

An initial repository for review, so that we can decide deliverables of value.

## Ideas

- I think Kong Open Source is quite a bit more developer friendly than NGINX
- LUA is quite a nice high level technology with good extensibility
- Kong has a built in cache that can be useful
- This repository might make a good basis for an article

## Kong Open Source

Are there any issues in promoting the open source version in terms of our relationship with Kong?

## Install Kong and Build the Plugin

- brew tap kong/kong
- brew install kong
- cd plugin
- luarocks make

This will deploy lua files under this location on my MacBook:

- /usr/local/Cellar/openresty@1.17.8.2/1.17.8.2/luarocks/share/lua/5.1/kong/plugins

## Running the Gateway + Phantom Token Plugin Locally

This sample uses the simplest developer option with no database and declarative config:

- cd local
- ./start.sh

Next send a bad token to the API gateway:

- curl -H "Authorization: Bearer XXX" http://localhost:8100/api

Then view the logged error details:

- cat logs/error.log

## Deploying the Gateway to Kubernetes

I will add some notes on this later, which involves these steps:

- Deploy Kong via its Helm Chart
- Use the Helm values file to specify API routes
- Supply the plugin as a Config Map
- Expose the gateway via an ingress over port 443

