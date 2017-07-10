#!/bin/sh

docker run --rm -it -v $PWD:/src docker-fukuro dub upgrade
sed -i -e 's/^.\+openssl.\+$//' dub.selections.json
docker run --rm -it -v $PWD:/src docker-fukuro dub build -b release
strip fukurod
tar cvzf moecoop.tgz fukurod LICENSE README.md resource
rm fukurod
