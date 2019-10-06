#!/bin/sh

dub upgrade
dub build -b release
strip fukurod
tar czf moecoop.tgz fukurod LICENSE README.md resource
rm fukurod
