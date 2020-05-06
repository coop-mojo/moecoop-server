#!/bin/sh

email=$1
token=$2
image=$3

cat > ~/.netrc <<EOF
machine api.heroku.com
    login ${email}
    password ${token}
EOF

echo "$token" | docker login -u=_ --password-stdin registry.heroku.com;
docker tag $image:latest registry.heroku.com/moecoop-server/web;
docker push registry.heroku.com/moecoop-server/web;

heroku container:release web --app moecoop-server;
