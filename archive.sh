#!/bin/sh

docker run --rm -it -v $PWD:/src moecoop/docker-fukuro dub upgrade
sed -i -e 's/^.\+openssl.\+$//' dub.selections.json
docker run --rm -it -v $PWD:/src moecoop/docker-fukuro dub build -b release
tar cvzf moecoop.tgz fukurod LICENSE README.md resource
