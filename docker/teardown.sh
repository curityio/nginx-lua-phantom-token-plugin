#!/bin/bash

#############################################
# Tear down base infrastructure after testing
#############################################

cd "$(dirname "${BASH_SOURCE[0]}")"
docker compose --profile "$PROFILE" --project-name phantomtoken down
