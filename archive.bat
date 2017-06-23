@echo off

dub upgrade
dub build -a %1 -b %2

powershell -Command Compress-Archive -Path fukurod.exe, LICENSE, README.md, libeay32.dll, ssleay32.dll, resource -DestinationPath moecoop-server-%1.zip

if %1==x86 (
    powershell -Command Compress-Archive -Path libevent.dll -DestinationPath moecoop-server-%1.zip -Update
)
if %1==x86_64 (
    powershell -Command Compress-Archive -Path migemo.dll -DestinationPath moecoop-server-%1.zip -Update
)

del fukurod.exe
