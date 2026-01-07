#!/bin/bash

APPNAME=<%= appName %>
NUMBER_OF_INSTANCES=<%= numberOfInstances %>

# Stop all app instances
for i in $(seq 1 $NUMBER_OF_INSTANCES); do
  if [ $i -eq 1 ]; then
    INSTANCE_NAME=$APPNAME
  else
    INSTANCE_NAME=$APPNAME-$i
  fi
  sudo docker rm -f $INSTANCE_NAME || :
  sudo docker network disconnect bridge -f $INSTANCE_NAME || :
done

sudo docker rm -f $APPNAME-frontend || :
sudo docker rm -f $APPNAME-nginx-letsencrypt || :
sudo docker rm -f $APPNAME-nginx-proxy || :

sudo docker network disconnect bridge -f $APPNAME-frontend || :
sudo docker network disconnect bridge -f $APPNAME-nginx-letsencrypt || :
sudo docker network disconnect bridge -f $APPNAME-nginx-proxy || :
