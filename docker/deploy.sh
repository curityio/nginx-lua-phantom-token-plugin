#!/bin/bash

##############################################
# Deploy base infrastructure to enable testing
##############################################

#
# Ensure that we are in the root folder
#
cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

#
# Get command line arguments
#
PROFILE=$1
if [ "$PROFILE" != 'openresty' ] && [ "$PROFILE" != 'kong' ] && [ "$PROFILE" != 'test' ]; then
  echo "Please specify 'openresty', 'kong' or 'test' as a command line parameter"
  exit 1
fi

#
# Prompt if required, and expand relative paths such as those containing ~
#
ADMIN_PASSWORD=Password1
if [ "$LICENSE_FILE_PATH" == '' ]; then
  read -t 60 -p 'Enter the path to the license file for the Curity Identity Server: ' LICENSE_FILE_PATH || :
fi
LICENSE_FILE_PATH=$(eval echo "$LICENSE_FILE_PATH")

#
# Check we have valid data before proceeding
#
if [ ! -f "$LICENSE_FILE_PATH" ]; then
  echo 'A valid LICENSE_FILE_PATH parameter was not supplied'
  exit 1
fi
LICENSE_KEY=$(cat "$LICENSE_FILE_PATH" | jq -r .License)
if [ "$LICENSE_KEY" == '' ]; then
  echo 'A valid license key was not found'
  exit 1 
fi

#
# When deploying the reverse proxy, build the custom Docker image, and use 'luarocks make' to deploy the plugin and its dependencies
#
if [ "$PROFILE" == 'kong' ]; then
  
  docker build -f docker/kong/Dockerfile --no-cache -t custom_kong:3.0.0-alpine .

elif [ "$PROFILE" == 'openresty' ]; then

  docker build -f docker/openresty/Dockerfile --no-cache -t custom_openresty:1.21.4.1-bionic .
fi
if [ $? -ne 0 ]; then
  echo "Problem encountered building the reverse proxy docker image"
  exit 1
fi

export LICENSE_KEY
export ADMIN_PASSWORD
if [ "$PROFILE" == 'test' ]; then
    
    #
    # When running the root test script, detach, wait for completion, run tests then tear down
    #
    docker compose --file ./docker/docker-compose.yml --profile "$PROFILE" --project-name phantomtoken up --build --force-recreate --detach
    echo 'Waiting for the Curity Identity Server ...'
    c=0; while [[ $c -lt 25 && "$(curl -fs -w ''%{http_code}'' localhost:8443)" != "404" ]]; do ((c++)); echo -n "."; sleep 1; done

else

    #
    # When testing deployed instances of Kong and OpenResty, run Docker components interactively, to view logs
    #
    docker compose --file ./docker/docker-compose.yml --profile "$PROFILE" --project-name phantomtoken up --build --force-recreate
fi
if [ $? -ne 0 ]; then
  echo "Problem encountered running the Docker deployment"
  exit 1
fi
