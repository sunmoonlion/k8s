try {
  load('/settings/common.js');
  const connection = connectAs(identity.root_username, identity.root_password, 'admin');
  requireResult(connection.getDB('admin').runCommand({ping: 1}).ok === 1, 'MongoDB ping failed');
  quit(0);
} catch (_) { quit(1); }
