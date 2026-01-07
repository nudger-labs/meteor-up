#!/bin/bash

APPNAME=<%= appName %>
CLIENTSIZE=<%= nginxClientUploadLimit %>
APP_PATH=/opt/$APPNAME
BUNDLE_PATH=$APP_PATH/current
ENV_FILE=$APP_PATH/config/env.list
PORT=<%= port %>
BIND=<%= bind %>
NGINX_PROXY_VERSION=latest
LETS_ENCRYPT_VERSION=latest
APP_IMAGE=mup-<%= appName.toLowerCase() %>
IMAGE=<% if(docker.remoteImage){ %><%= docker.remoteImage %>
  <% } else { %>$APP_IMAGE:latest <% } %>
VOLUME="--volume=$BUNDLE_PATH:/bundle"
LOCAL_IMAGE=false
NUMBER_OF_INSTANCES=<%= numberOfInstances %>

<% if (!privateRegistry) { %>
# sudo docker image inspect $IMAGE >/dev/null || IMAGE=<%= docker.image %>
if sudo docker image inspect $IMAGE >/dev/null; then
  VOLUME=""
  LOCAL_IMAGE=true
fi
<% } else { %>
  VOLUME=""
  LOCAL_IMAGE=true
  # We want this pull to fail on error since
  # otherwise we might try to run an old version of the app
  set -e
  sudo docker pull $IMAGE
  set +e
<% } %>

echo "Image" $IMAGE
echo "Volume" $VOLUME

# We want this message with the errors in stderr when shown to the user.
>&2 echo "Removing docker containers. Errors about nonexistent endpoints and containers are normal.";

# Remove previous version of the app instances, if exists
for i in $(seq 1 $NUMBER_OF_INSTANCES); do
  if [ $i -eq 1 ]; then
    INSTANCE_NAME=$APPNAME
  else
    INSTANCE_NAME=$APPNAME-$i
  fi
  
  sudo docker rm -f $INSTANCE_NAME
  
  # Remove container network if still exists
  sudo docker network disconnect bridge -f $INSTANCE_NAME
  <% for(var network in docker.networks) { %>
  sudo docker network disconnect <%=  docker.networks[network] %> -f $INSTANCE_NAME
  <% } %>
done

# Remove frontend container if exists
sudo docker rm -f $APPNAME-frontend
sudo docker network disconnect bridge -f $APPNAME-frontend

# Remove let's encrypt containers if exists
sudo docker rm -f $APPNAME-nginx-letsencrypt
sudo docker network disconnect bridge -f $APPNAME-nginx-letsencrypt

sudo docker rm -f $APPNAME-nginx-proxy
sudo docker network disconnect bridge -f $APPNAME-nginx-proxy

>&2 echo "Finished removing docker containers"

# We don't need to fail the deployment because of a docker hub downtime
if [ $LOCAL_IMAGE == "false" ]; then
  set +e
  sudo docker pull $IMAGE
  echo "Pulled "$IMAGE
  set -e

else
  set -e
fi

# Start multiple instances
for i in $(seq 1 $NUMBER_OF_INSTANCES); do
  if [ $i -eq 1 ]; then
    INSTANCE_NAME=$APPNAME
    INSTANCE_PORT=$PORT
  else
    INSTANCE_NAME=$APPNAME-$i
    INSTANCE_PORT=$((PORT + i - 1))
  fi
  
  echo "Starting instance $INSTANCE_NAME on port $INSTANCE_PORT"
  
  # Build log options with instance-specific tag
  LOG_OPTS=""
  <% if(logConfig && logConfig.driver)  { %>LOG_OPTS="$LOG_OPTS --log-driver=<%= logConfig.driver %>"<% } %>
  <% for(var option in logConfig.opts) { %>
  <% if(option === 'tag') { %>
  # Append instance number to tag for multi-instance deployments
  if [ $i -eq 1 ] && [ $NUMBER_OF_INSTANCES -eq 1 ]; then
    LOG_OPTS="$LOG_OPTS --log-opt <%= option %>=<%= logConfig.opts[option] %>"
  else
    LOG_OPTS="$LOG_OPTS --log-opt <%= option %>=<%= logConfig.opts[option] %>-$i"
  fi
  <% } else { %>
  LOG_OPTS="$LOG_OPTS --log-opt <%= option %>=<%= logConfig.opts[option] %>"
  <% } %>
  <% } %>

  sudo docker run \
    -d \
    --restart=always \
    $VOLUME \
    <% if((sslConfig && typeof sslConfig.autogenerate === "object") || (typeof proxyConfig === "object" && !proxyConfig.loadBalancing && numberOfInstances == 1 && !multiServer))  { %> \
    --expose=<%= docker.imagePort %> \
    <% } else { %> \
    --publish=$BIND:$INSTANCE_PORT:<%= docker.imagePort %> \
    <% } %> \
    --hostname="$HOSTNAME-$INSTANCE_NAME" \
    --env-file=$ENV_FILE \
    $LOG_OPTS \
    <% for(var volume in volumes) { %>-v <%= volume %>:<%= volumes[volume] %> <% } %> \
    <% for(var args in docker.args) { %> <%- docker.args[args] %> <% } %> \
    <% if(sslConfig && typeof sslConfig.autogenerate === "object")  { %> \
      -e "VIRTUAL_HOST=<%= sslConfig.autogenerate.domains %>" \
      -e "LETSENCRYPT_HOST=<%= sslConfig.autogenerate.domains %>" \
      -e "LETSENCRYPT_EMAIL=<%= sslConfig.autogenerate.email %>" \
      -e "HTTPS_METHOD=noredirect" \
    <% } %> \
    --name=$INSTANCE_NAME \
    $IMAGE
  echo "Ran instance $INSTANCE_NAME"
done
# When using a private docker registry, the cleanup run in 
# Prepare Bundle is only done on one server, so we also
# cleanup here so the other servers don't run out of disk space
<% if (privateRegistry) { %>
  echo "pruning images"
  sudo docker image prune -f || true
<% } %>

if [[ $VOLUME == "" ]]; then
  # The app starts much faster when prepare bundle is enabled,
  # so we do not need to wait as long
  sleep 3s
else
  sleep 15s
fi

<% if(typeof sslConfig === "object") { %>
   <% if(typeof sslConfig.autogenerate === "object")  { %>
    echo "Running autogenerate"
    # Get the nginx template for nginx-gen
    wget https://raw.githubusercontent.com/jwilder/nginx-proxy/master/nginx.tmpl -O /opt/$APPNAME/config/nginx.tmpl

    # Update nginx config based on user input or default passed by js
sudo cat <<EOT > /opt/$APPNAME/config/nginx-default.conf
client_max_body_size $CLIENTSIZE;
EOT

    # We don't need to fail the deployment because of a docker hub downtime
    set +e
    sudo docker pull jrcs/letsencrypt-nginx-proxy-companion:$LETS_ENCRYPT_VERSION
    sudo docker pull zodern/nginx-proxy:$NGINX_PROXY_VERSION
    set -e

    echo "Pulled autogenerate images"
    sudo docker run -d -p 80:80 -p 443:443 \
      --name $APPNAME-nginx-proxy \
      --restart=always \
      -e "DEFAULT_HOST=<%= sslConfig.autogenerate.domains.split(',')[0] %>" \
      -v /opt/$APPNAME/config/nginx-default.conf:/etc/nginx/conf.d/my_proxy.conf:ro \
      -v /opt/$APPNAME/certs:/etc/nginx/certs:ro \
      -v /opt/$APPNAME/config/vhost.d:/etc/nginx/vhost.d \
      -v /opt/$APPNAME/config/html:/usr/share/nginx/html \
      -v /var/run/docker.sock:/tmp/docker.sock:ro \
      zodern/nginx-proxy:$NGINX_PROXY_VERSION
      echo "Ran nginx-proxy"
    sleep 15s

    sudo docker run -d \
      --name $APPNAME-nginx-letsencrypt \
      --restart=always\
      --volumes-from $APPNAME-nginx-proxy \
      -v /opt/$APPNAME/certs:/etc/nginx/certs:rw \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      jrcs/letsencrypt-nginx-proxy-companion:$LETS_ENCRYPT_VERSION
    echo "Ran jrcs/letsencrypt-nginx-proxy-companion"
    <% } else { %>
    # We don't need to fail the deployment because of a docker hub downtime
    set +e
    sudo docker pull <%= docker.imageFrontendServer %>
    set -e
    sudo docker run \
      -d \
      --restart=always \
      --volume=/opt/$APPNAME/config/bundle.crt:/bundle.crt \
      --volume=/opt/$APPNAME/config/private.key:/private.key \
      --link=$APPNAME:backend \
      --publish=$BIND:<%= sslConfig.port %>:443 \
      --name=$APPNAME-frontend \
      <%= docker.imageFrontendServer %> /start.sh
  <% } %>
<% } %>

<% for(var network in docker.networks) { %>
  for i in $(seq 1 $NUMBER_OF_INSTANCES); do
    if [ $i -eq 1 ]; then
      INSTANCE_NAME=$APPNAME
    else
      INSTANCE_NAME=$APPNAME-$i
    fi
    sudo docker network connect <%=  docker.networks[network] %> $INSTANCE_NAME
  done
<% } %>
