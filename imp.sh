#!/usr/bin/env bash

docker build -t imp .

for setting in $(grep "^[a-zA-Z_].*=" settings); do
    export $setting
done

fitstat="/dev/$(ls -l /dev/serial/by-id/*fit_Stat* | rev | cut -d"/" -f1 | rev)"
if [ "$(docker inspect imp --format '{{.State.Status}}')" == "running" ]; then
    docker stop imp
fi
if [ "$(docker inspect imp --format '{{.State.Status}}')" == "exited" ]; then
    docker rm imp
fi
docker run \
    --device $fitstat:/dev/fitstat \
    -e SENSU_HOST \
    -e SENSU_USER \
    -e SENSU_PASSWORD \
    -e SENSU_NAMESPACE \
    --restart no \
    --read-only=true \
    --name="imp" \
    -v $(pwd)/imp.rb:/imp.rb \
    imp ruby /imp.rb

