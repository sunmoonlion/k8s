try {
  load('/settings/common.js');
  const connection = connectAs(identity.root_username, identity.root_password, 'admin');
  const admin = connection.getDB('admin');
  const expected = {_id: process.env.MONGODB_REPLICA_SET, members: [{_id: 0, host: endpoint}]};
  const status = admin.runCommand({replSetGetStatus: 1});
  if (status.ok !== 1) {
    requireResult(status.code === 94, 'Replica set state is not a fresh uninitialized instance');
    requireResult(admin.runCommand({replSetInitiate: expected}).ok === 1, 'Replica set initialization failed');
  }
  let primary = false;
  for (let i = 0; i < 90; i++) {
    if (admin.runCommand({hello: 1}).isWritablePrimary === true) { primary = true; break; }
    sleep(1000);
  }
  requireResult(primary, 'Replica set primary election timed out');
  const config = admin.runCommand({replSetGetConfig: 1}).config;
  requireResult(config._id === expected._id && config.members.length === 1 && config.members[0]._id === 0 && config.members[0].host === endpoint, 'Existing replica set differs; automatic reconfiguration is forbidden');
  const database = connection.getDB(process.env.MONGODB_ACCEPTANCE_DATABASE);
  const user = database.getUser(identity.acceptance_username);
  if (!user) database.createUser({user: identity.acceptance_username, pwd: identity.acceptance_password, roles: [{role: 'readWrite', db: database.getName()}]}, {w: 'majority', wtimeout: 10000});
  else requireResult(user.roles.length === 1 && user.roles[0].role === 'readWrite' && user.roles[0].db === database.getName(), 'Existing acceptance account has unexpected privileges');
  connectAs(identity.acceptance_username, identity.acceptance_password, database.getName());
  print(JSON.stringify({initialized: true, single_member_replica_set: true, distinct_limited_identity: true}));
} catch (error) {
  print(JSON.stringify({initialized: false, error: error.codeName || (error.code ? 'MongoDB code ' + error.code : error.message)}));
  quit(1);
}
