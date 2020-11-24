import debug from 'debug';
import nodemiral from '@zodern/nodemiral';

const log = debug('mup:module:mongo');

export function logs(api) {
  log('exec => mup mongo logs');

  const args = api.getArgs();
  const sessions = api.getSessions(['mongo']);

  // remove mongo from args sent to docker
  args.shift();

  return api.getDockerLogs('mongodb', sessions, args);
}

export function setup(api) {
  log('exec => mup mongo setup');
  const mongoConfig = api.getConfig().mongo;

  if (!mongoConfig) {
    // could happen when running "mup mongo setup"
    console.log(
      'Not setting up built-in mongodb since there is no mongo config'
    );

    return;
  }

  const mongoSessions = api.getSessions(['mongo']);
  const meteorSessions = api.getSessions(['app']);

  if (meteorSessions.length !== 1) {
    console.log(
      'To use mup built-in mongodb setup, you should have only one meteor app server. To have more app servers, use an external mongodb setup'
    );

    return;
  } else if (mongoSessions[0]._host !== meteorSessions[0]._host) {
    console.log(
      'To use mup built-in mongodb setup, you should have both meteor app and mongodb on the same server'
    );

    return;
  }

  const list = nodemiral.taskList('Setup Mongo');

  list.executeScript('Setup Environment', {
    script: api.resolvePath(__dirname, 'assets/mongo-setup.sh')
  });

  list.copy('Copying Mongo Config', {
    src: api.resolvePath(__dirname, 'assets/templates/start.sh'),
    dest: '/opt/mongodb/mongo-start-new.sh',
    vars: {
      mongoVersion: mongoConfig.version,
      mongoDbDir: '/var/lib/mongodb'
    }
  });

  const sessions = api.getSessions(['mongo']);

  return api.runTaskList(list, sessions, { verbose: api.verbose });
}

export function start(api) {
  log('exec => mup mongo start');

  const mongoSessions = api.getSessions(['mongo']);
  const meteorSessions = api.getSessions(['app']);

  if (
    meteorSessions.length !== 1 ||
    mongoSessions[0]._host !== meteorSessions[0]._host
  ) {
    log('Skipping mongodb start. Incompatible config');

    return;
  }

  const list = nodemiral.taskList('Start Mongo');

  list.executeScript('Start Mongo', {
    script: api.resolvePath(__dirname, 'assets/mongo-start.sh'),
    vars: {
      mongoVersion: config.version || '3.4.1',
      mongoBindIp: config.bindIp || '127.0.0.1',
      mongoReplicasetName: config.replicasetName || 'meteor',
      mongoDbDir: '/var/lib/mongodb'
    }
  });

  const sessions = api.getSessions(['mongo']);

  return api.runTaskList(list, sessions, { verbose: api.verbose });
}

export function stop(api) {
  log('exec => mup mongo stop');
  const list = nodemiral.taskList('Stop Mongo');

  list.executeScript('Stop Mongo', {
    script: api.resolvePath(__dirname, 'assets/mongo-stop.sh')
  });

  const sessions = api.getSessions(['mongo']);

  return api.runTaskList(list, sessions, { verbose: api.verbose });
}

export async function status(api) {
  const config = api.getConfig();

  if (!config.mongo) {
    return;
  }
  const mongoServer = Object.keys(config.mongo.servers)[0];
  const server = config.servers[mongoServer];

  let { output: dockerStatus } = await api.runSSHCommand(
    server,
    'docker inspect mongodb --format "{{json .}}"'
  );
  const mongoCommand = '"JSON.stringify(db.runCommand({serverStatus: 1, metrics: 0, wiredTiger: 1}))"';
  let {
    output: mongoStatus
  } = await api.runSSHCommand(
    server,
    `docker exec mongodb mongo --eval ${mongoCommand} --quiet`
  );

  try {
    mongoStatus = JSON.parse(mongoStatus);
    dockerStatus = JSON.parse(dockerStatus);
  } catch (e) {
    const display = new api.statusHelpers.StatusDisplay(
      'Mongo Status'
    );
    display.addLine(' Stopped', 'red');
    display.show();

    return;
  }

  const mongoVersion = mongoStatus.version;
  const mongoBindIp = mongoStatus.bindIp;
  const mongoReplicasetName = mongoStatus.replicasetName;
  const connections = mongoStatus.connections.current;
  const storageEngine = mongoStatus.storageEngine.name;

  const containerStatus = dockerStatus.State.Status;
  let statusColor = 'green';
  const createdTime = dockerStatus.Created;
  const restartCount = dockerStatus.RestartCount;
  let restartCountColor = 'green';

  if (dockerStatus.State.Restarting) {
    statusColor = 'yellow';
  } else if (dockerStatus.State.Running !== true) {
    statusColor = 'red';
  }

  const hour = 1000 * 60 * 60;
  const upTime = new Date(dockerStatus.State.FinishedAt).getTime() -
     new Date(dockerStatus.Created).getTime();

  if (restartCount > 0 && upTime / hour <= restartCount) {
    restartCountColor = 'red';
  } else if (restartCount > 1) {
    restartCountColor = 'yellow';
  }

  const display = new api.statusHelpers.StatusDisplay('Mongo Status');
  display.addLine(`${containerStatus} on server ${server.host}`, statusColor);
  display.addLine(`Restarted ${restartCount} times`, restartCountColor);
  display.addLine(`Running since ${createdTime}`);
  display.addLine(`Version ${mongoVersion}`);
  display.addLine(`BindIP ${mongoBindIp}`);
  display.addLine(`Replicaset Name ${mongoReplicasetName}`);
  display.addLine(`Connections: ${connections}`);
  display.addLine(`Storage Engine: ${storageEngine}`);
  display.show(api.getOptions().overview);
}
