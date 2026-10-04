// Actual bounded read/write, commit/abort, TLS and authorization checks.
let collection = null;
let acceptanceFailed = false;
try {
  load('/settings/common.js');
  const adminConnection = connectAs(identity.root_username, identity.root_password, 'admin');
  const admin = adminConnection.getDB('admin');
  const version = admin.runCommand({buildInfo: 1}).version;
  requireResult(version === process.env.MONGODB_VERSION, 'Running MongoDB version differs from lock');
  const hello = admin.runCommand({hello: 1});
  requireResult(hello.isWritablePrimary && hello.setName === process.env.MONGODB_REPLICA_SET, 'Replica set is not the expected writable primary');
  const databaseName = process.env.MONGODB_ACCEPTANCE_DATABASE;
  const connection = connectAs(identity.acceptance_username, identity.acceptance_password, databaseName);
  const database = connection.getDB(databaseName);
  const name = 'check_' + new ObjectId().toHexString();
  collection = database.getCollection(name);
  collection.insertOne({_id: 'crud', value: '中文写入'}, {writeConcern: {w: 'majority', wtimeout: 10000}});
  requireResult(collection.findOne({_id: 'crud'}).value === '中文写入', 'MongoDB read differs');
  collection.updateOne({_id: 'crud'}, {$set: {value: '已更新'}});
  requireResult(collection.findOne({_id: 'crud'}).value === '已更新', 'MongoDB update differs');
  collection.deleteOne({_id: 'crud'});
  requireResult(collection.countDocuments({_id: 'crud'}) === 0, 'MongoDB delete failed');
  const session = connection.startSession();
  try {
    const transactional = session.getDatabase(databaseName).getCollection(name);
    session.startTransaction({writeConcern: {w: 'majority', wtimeout: 10000}, readConcern: {level: 'snapshot'}});
    transactional.insertMany([{_id: 'commit1'}, {_id: 'commit2'}]);
    session.commitTransaction();
    requireResult(collection.countDocuments({_id: {$in: ['commit1','commit2']}}) === 2, 'Multi-document commit failed');
    session.startTransaction({writeConcern: {w: 'majority', wtimeout: 10000}});
    transactional.insertOne({_id: 'abort'});
    session.abortTransaction();
    requireResult(collection.countDocuments({_id: 'abort'}) === 0, 'Transaction abort did not restore prior state');
  } finally { session.endSession(); }
  deny(() => connection.getDB('admin').runCommand({usersInfo: 1}));
  deny(() => connection.getDB('sunmoon_foreign').runCommand({insert: name, documents: [{value: 1}]}));
  deny(() => new Mongo(uri).getDB(databaseName).auth(identity.acceptance_username, 'invalid_' + new ObjectId().toHexString()));
  const anonymous = new Mongo(uri);
  deny(() => anonymous.getDB(databaseName).runCommand({find: name}));
  print(JSON.stringify({passed: true, version, tls_chain_and_hostname: true, single_member_primary: true, least_privilege_crud: true, multi_document_commit: true, transaction_abort: true, anonymous_read_denied: true, wrong_password_denied: true, admin_action_denied: true, foreign_database_write_denied: true, scope: 'Internal MongoDB protocol and limited acceptance account; not business integration, HA or backup recovery'}));
} catch (error) {
  acceptanceFailed = true;
  print(JSON.stringify({passed: false, error: error.codeName || (error.code ? 'MongoDB code ' + error.code : error.message)}));
} finally { if (collection) collection.drop(); }
if (acceptanceFailed) quit(1);
