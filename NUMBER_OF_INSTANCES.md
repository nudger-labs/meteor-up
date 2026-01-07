# Multiple Instances Feature

This feature allows you to run multiple instances of the same app on each server with automatic load balancing.

## Overview

The `numberOfInstances` configuration option enables you to deploy multiple Docker containers of your app on each server. Each server can have a different number of instances. The nginx reverse proxy automatically load balances traffic between all instances across all servers.

## Configuration

### Basic Configuration

Add the `numberOfInstances` option to each server in your app configuration:

```js
module.exports = {
  servers: {
    one: {
      host: '1.2.3.4',
      username: 'root',
      pem: './server_key'
    },
    two: {
      host: '5.6.7.8',
      username: 'root',
      pem: './server_key'
    }
  },
  app: {
    name: 'myapp',
    path: '../',
    servers: { 
      one: {
        // Run 3 instances on server one
        numberOfInstances: 3
      },
      two: {
        // Run 2 instances on server two
        numberOfInstances: 2
      }
    },
    
    env: {
      ROOT_URL: 'https://myapp.com',
      MONGO_URL: 'mongodb://localhost/meteor',
      PORT: 80
    },
    docker: {
      image: 'abernix/meteord:base'
    }
  },
  
  // Proxy is required for load balancing
  proxy: {
    domains: 'myapp.com',
    ssl: {
      letsEncryptEmail: 'email@example.com'
    }
  }
};
```

### Sticky Session Configuration

By default, sticky sessions use `ip_hash` to route users to the same instance. You can configure different sticky session methods in the proxy configuration:

```js
app: {
  name: 'myapp',
  path: '../',
  servers: { 
    one: {
      numberOfInstances: 3
    }
  },
  env: {
    ROOT_URL: 'https://myapp.com',
    MONGO_URL: 'mongodb://localhost/meteor'
  }
},

proxy: {
  domains: 'myapp.com',
  ssl: {
    letsEncryptEmail: 'email@example.com'
  },
  // Configure sticky session method
  stickySessionMethod: 'cookie',  // Options: 'ip_hash', 'cookie', 'none'
  stickySessionCookie: 'meteor_login_token'  // Cookie name to use (default: 'meteor_login_token')
}
```

**Sticky Session Methods:**

- **`ip_hash`** (default): Routes based on client IP address. Best for most use cases.
  - Pros: Simple, works without cookies
  - Cons: Users behind NAT/proxy may all hit the same instance

- **`cookie`**: Routes based on session cookie. Best for applications with session cookies.
  - Pros: More accurate user-to-instance mapping
  - Cons: Requires cookies to be set by your application
  - Default cookie: `meteor_login_token` (configurable via `stickySessionCookie`)

- **`none`**: No sticky sessions, pure round-robin load balancing.
  - Pros: Most even distribution of load
  - Cons: Users may hit different instances on each request (requires stateless app or external session store)

## How It Works

1. **Container Naming**: On each server, instances are named as follows:
   - First instance: `myapp`
   - Second instance: `myapp-2`
   - Third instance: `myapp-3`
   - And so on...

2. **Port Assignment**: On each server, each instance runs on a consecutive port:
   - First instance: PORT (e.g., 80)
   - Second instance: PORT + 1 (e.g., 81)
   - Third instance: PORT + 2 (e.g., 82)
   - And so on...

3. **Load Balancing**: The nginx proxy automatically configures an upstream block with all instances across all servers and distributes traffic between them.

4. **Sticky Sessions**: By default, sticky sessions (ip_hash) are enabled to ensure users stay connected to the same instance.

## Requirements

- **Per-Server Configuration**: Each server can have a different number of instances configured independently.
- **Proxy Required**: The reverse proxy must be configured for load balancing to work when using multiple instances.
- **Port Range**: Ensure your firewall allows the port range needed for all instances (though they're only exposed internally to nginx).

## Limitations

- Maximum of 10 instances per server (configurable in validation schema)
- Only works with non-swarm deployments
- All instances share the same environment variables and settings

## Use Cases

- **Increased Throughput**: Handle more concurrent requests by running multiple instances
- **Better CPU Utilization**: Utilize multiple CPU cores on a single server
- **Zero-Downtime Deploys**: With multiple instances, some can stay running while others restart
- **Cost Optimization**: Maximize resource usage on a single server before scaling to multiple servers

## Commands

All standard mup commands work with multiple instances:

```bash
# Deploy with multiple instances
mup deploy

# Stop all instances
mup stop

# Restart all instances
mup restart

# View logs (shows logs from first instance)
mup logs

# Check status
mup status
```

## Example Configurations

### Single Server with Multiple Instances
```js
app: {
  servers: {
    one: {
      numberOfInstances: 3
    }
  },
  // ... other config
}
```

### Multiple Servers with Different Instance Counts
```js
app: {
  servers: {
    one: {
      numberOfInstances: 5  // High-spec server
    },
    two: {
      numberOfInstances: 2  // Lower-spec server
    },
    three: {
      // No numberOfInstances specified, defaults to 1
    }
  },
  env: {
    PORT: 3000,
    // ... other env vars
  }
}
```

### Mixed Configuration
```js
app: {
  servers: {
    production: {
      numberOfInstances: 4
    },
    staging: {
      numberOfInstances: 1
    }
  }
}
```

## Troubleshooting

1. **Instances not starting**: Check that you have enough memory and CPU resources
2. **Load balancing not working**: Ensure the proxy is configured and running
3. **Port conflicts**: Make sure the port range is available on your server

## Migration from Single Instance

To migrate from a single instance to multiple instances per server:

1. Add `numberOfInstances` to each server in your config:
   ```js
   servers: {
     one: {
       numberOfInstances: 3
     }
   }
   ```
2. Ensure proxy is configured
3. Run `mup deploy`

The deployment will automatically:
- Stop the old single instance on each server
- Start multiple new instances on each server
- Configure nginx load balancing across all instances
- Verify the deployment

## Performance Considerations

- Each instance consumes memory, so ensure your server has adequate RAM
- Monitor CPU usage to determine optimal number of instances
- Consider your database connection limits (each instance creates its own connections)
- Start with 2-3 instances and scale up based on monitoring data
