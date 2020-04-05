# Imp

The pesky little bat-like monitoring f(r)iend

## What is Imp

Imp is a ruby script that polls Sensu (SensuGo, the monitoring software) for new incidents every minute. When new unsilenced incidents occur, fitstat lights up with a color reflecting the most severe incident

## Starting Imp

First, create the settings file `settings` at the root of the repo and set the following:
```
SENSU_HOST=sensu.example.com
SENSU_USER=admin
SENSU_PASSWORD=adminpassword
SENSU_NAMESPACE=default
```
Then:
```
./imp.sh
```
This will build a docker container, find the connected fitStat-USB device, and start Imp

## fitStat Colors

Light blue: Default color when plugging in fitStat-USB
Purple: Imp just started and is initializing
Yellow: Most severe new incident returned 1 (warning)
Red: Most severe new incident returned 2 (critical)
Teal: Most severe new incident returned 3 >= (unknown)

