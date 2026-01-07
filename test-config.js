// Test configuration for numberOfInstances feature
// Replace with your actual server details

module.exports = {
  servers: {
    one: {
      host: 'your-server-ip',
      username: 'root',
      // Use either pem or password
      pem: '~/.ssh/id_rsa',
      // password: 'your-password'
    }
  },
  
  app: {
    name: 'test-app',
    path: '../path-to-your-meteor-app',
    
    servers: {
      one: {
        // Test with 2 instances
        numberOfInstances: 2
      }
    },
    
    buildOptions: {
      serverOnly: true
    },
    
    env: {
      ROOT_URL: 'http://your-server-ip',
      MONGO_URL: 'mongodb://localhost/meteor',
      PORT: 3000
    },
    
    docker: {
      image: 'abernix/meteord:base'
    }
  },
  
  // Optional: Add proxy for load balancing
  proxy: {
    domains: 'your-domain.com',
    ssl: {
      letsEncryptEmail: 'your-email@example.com'
    }
  },
  
  mongo: {
    version: '4.4.6',
    servers: {
      one: {}
    }
  }
};
