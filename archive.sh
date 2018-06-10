#!/bin/sh

dub upgrade
sed -i -e 's/^.\+openssl.\+$//' dub.selections.json
dub build -b release
strip fukurod
tar czf moecoop.tgz fukurod LICENSE README.md resource
rm fukurod
