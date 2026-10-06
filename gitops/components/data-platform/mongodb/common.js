// Passwords are read from private files, never command arguments or logs.
var fs = require('fs');
var identity = JSON.parse(fs.readFileSync('/run/auth/input.json', 'utf8'));
var endpoint = process.env.MONGODB_HOST + ':' + process.env.MONGODB_PORT;
var uri = 'mongodb://' + endpoint + '/?directConnection=true&tls=true&tlsCAFile=/run/auth/ca.crt&serverSelectionTimeoutMS=10000&connectTimeoutMS=10000&socketTimeoutMS=20000';
function requireResult(ok, message) { if (!ok) throw new Error(message); }
function connectAs(user, password, database) {
  const connection = new Mongo(uri);
  requireResult(connection.getDB(database).auth(user, password).ok === 1, 'MongoDB authentication failed');
  return connection;
}
function deny(action) {
  let denied = false;
  try { const result = action(); denied = result && result.ok === 0 && [13,18].includes(result.code); }
  catch (error) { denied = [13,18].includes(error.code); }
  requireResult(denied, 'MongoDB unauthorized action was not rejected');
}
