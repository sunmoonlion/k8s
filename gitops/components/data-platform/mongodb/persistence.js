// Operator-triggered, nonce-scoped acceptance across an actual Pod replacement.
try {
  load('/settings/common.js');
  const nonce = process.env.MONGODB_PERSISTENCE_NONCE;
  const action = process.env.MONGODB_PERSISTENCE_ACTION;
  requireResult(/^[a-f0-9]{32}$/.test(nonce), 'Invalid persistence acceptance nonce');
  const connection = connectAs(identity.acceptance_username, identity.acceptance_password, process.env.MONGODB_ACCEPTANCE_DATABASE);
  const collection = connection.getDB(process.env.MONGODB_ACCEPTANCE_DATABASE).getCollection('restart_' + nonce);
  if (action === 'create') {
    requireResult(collection.countDocuments({}) === 0, 'Persistence acceptance collection already exists');
    collection.insertOne({_id: nonce, value: '重启后保留'}, {writeConcern: {w: 'majority', j: true, wtimeout: 10000}});
  } else if (action === 'verify') {
    requireResult(collection.findOne({_id: nonce}).value === '重启后保留' && collection.countDocuments({}) === 1, 'Persistent acceptance data differs after restart');
  } else if (action === 'remove') {
    requireResult(collection.findOne({_id: nonce}).value === '重启后保留' && collection.countDocuments({}) === 1, 'Refuse removing a foreign acceptance collection');
    collection.drop();
  } else throw new Error('Unsupported persistence acceptance action');
  print(JSON.stringify({passed: true, action, nonce}));
} catch (error) {
  print(JSON.stringify({passed: false, error: error.codeName || (error.code ? 'MongoDB code ' + error.code : error.message)}));
  quit(1);
}
