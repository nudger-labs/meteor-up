# Testing numberOfInstances Feature Locally

## Prerequisites

1. A test server (can be a local VM, DigitalOcean droplet, AWS EC2, etc.)
2. A Meteor app to deploy
3. SSH access to the server

## Setup Steps

### 1. Link the Local mup Package

From the meteor-up directory:

```bash
# Create a global link to your local mup
npm link

# Verify it's using your local version
which mup
mup --version
```

### 2. Create a Test Meteor App (if you don't have one)

```bash
cd ~
meteor create test-meteor-app
cd test-meteor-app
```

### 3. Initialize mup Configuration

```bash
# In your meteor app directory
mup init
```

### 4. Configure numberOfInstances

Edit the generated `mup.js` file:

```js
module.exports = {
  servers: {
    one: {
      host: 'YOUR_SERVER_IP',
      username: 'root',
      pem: '~/.ssh/id_rsa'
    }
  },
  
  app: {
    name: 'test-app',
    path: '../',
    
    servers: {
      one: {
        numberOfInstances: 2  // Test with 2 instances
      }
    },
    
    buildOptions: {
      serverOnly: true
    },
    
    env: {
      ROOT_URL: 'http://YOUR_SERVER_IP',
      MONGO_URL: 'mongodb://localhost/meteor',
      PORT: 3000
    },
    
    docker: {
      image: 'abernix/meteord:base'
    }
  },
  
  proxy: {
    domains: 'YOUR_DOMAIN_OR_IP',
    ssl: {
      letsEncryptEmail: 'your@email.com'
    }
  },
  
  mongo: {
    version: '4.4.6',
    servers: {
      one: {}
    }
  }
};
```

### 5. Deploy and Test

```bash
# Setup the server
mup setup

# Deploy the app
mup deploy
```

### 6. Verify Multiple Instances

SSH into your server and check:

```bash
# List running containers
docker ps

# You should see:
# - test-app (first instance)
# - test-app-2 (second instance)
# - mup-nginx-proxy (load balancer)

# Check nginx upstream configuration
docker exec mup-nginx-proxy cat /etc/nginx/vhost.d/YOUR_DOMAIN_upstream

# You should see both instances listed:
# server YOUR_SERVER_IP:3000;
# server YOUR_SERVER_IP:3001;

# Test load balancing
curl http://YOUR_SERVER_IP
# Make multiple requests and check logs to see different instances handling requests

# View logs from each instance
docker logs test-app
docker logs test-app-2
```

## Testing Different Scenarios

### Test 1: Single Server, Multiple Instances
```js
servers: {
  one: {
    numberOfInstances: 3
  }
}
```

### Test 2: Multiple Servers, Different Instance Counts
```js
servers: {
  one: {
    numberOfInstances: 2
  },
  two: {
    numberOfInstances: 3
  }
}
```

### Test 3: Mixed Configuration
```js
servers: {
  one: {
    numberOfInstances: 2
  },
  two: {
    // No numberOfInstances - should default to 1
  }
}
```

## Debugging

### Check Container Status
```bash
docker ps -a
docker inspect test-app
docker inspect test-app-2
```

### Check Logs
```bash
# From your local machine
mup logs

# On the server
docker logs test-app
docker logs test-app-2
docker logs mup-nginx-proxy
```

### Check Nginx Configuration
```bash
# On the server
docker exec mup-nginx-proxy nginx -t
docker exec mup-nginx-proxy cat /etc/nginx/conf.d/default.conf
```

### Verify Port Bindings
```bash
# On the server
netstat -tlnp | grep docker
# Should show ports 3000, 3001 (for 2 instances)
```

## Quick Local VM Test (Using Vagrant)

If you want to test without a remote server:

1. Create a Vagrantfile:
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  end
end
```

2. Start the VM:
```bash
vagrant up
```

3. Use `192.168.56.10` as your server IP in mup.js

## Cleanup

```bash
# Stop and remove all containers
mup stop

# Or destroy everything
mup destroy --force
```

## Expected Behavior

✅ Multiple containers created with names: `test-app`, `test-app-2`, `test-app-3`, etc.
✅ Each instance on consecutive ports: 3000, 3001, 3002, etc.
✅ Nginx upstream configured with all instances
✅ Load balancing working across all instances
✅ All instances start/stop/restart together
