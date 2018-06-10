#!/bin/sh

token=$1
image=$2

docker login -u=_ -p="$token" registry.heroku.com;
docker tag $image:latest registry.heroku.com/moecoop-server/web;
docker push registry.heroku.com/moecoop-server/web;
