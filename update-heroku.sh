#!/bin/sh

token=$1
image=$2

echo "$token" | docker login -u=_ --password-stdin registry.heroku.com;
docker tag $image:latest registry.heroku.com/moecoop-server/web;
docker push registry.heroku.com/moecoop-server/web;
