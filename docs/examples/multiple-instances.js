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
        // Each instance will run on a consecutive port (80, 81, 82)
        // The proxy will automatically load balance between them
        numberOfInstances: 3
      },
      two: {
        // Run 2 instances on server two
        numberOfInstances: 2
      }
    },
    
    buildOptions: {
      serverOnly: true
    },
    env: {
      ROOT_URL: 'https://myapp.com',
      MONGO_URL: 'mongodb://localhost/meteor',
      PORT: 80
    },
    docker: {
      image: 'abernix/meteord:base'
    },
    deployCheckWaitTime: 60
  },
  
  // Proxy configuration is required for load balancing
  proxy: {
    domains: 'myapp.com',
    ssl: {
      letsEncryptEmail: 'email@example.com'
    }
  },
  
  mongo: {
    port: 27017,
    version: '3.4.1',
    servers: {
      one: {}
    }
  }
};
