"""Harbor 2.15.2 account API. Native Ansible controls backups, config and lifecycle."""
from account_protocol import Transport
from account_files import require


def inspect(settings, password):
    client = Transport(settings['hostname'], settings['port'], settings['ca'])
    status, user = client.request('GET', '/api/v2.0/users/current', credentials=('admin', password))
    if status == 401:
        return None
    require(status == 200 and isinstance(user, dict), 'Harbor identity API unavailable')
    require(user.get('username') == 'admin' and user.get('sysadmin_flag') is True and user.get('user_id') == 1,
            'Harbor account identity or administrator privileges differ')
    status, configuration = client.request('GET', '/api/v2.0/configurations', credentials=('admin', password))
    require(status == 200 and configuration.get('auth_mode', {}).get('value') == 'db_auth', 'Harbor native database authentication is required')
    return {'username': 'admin', 'user_id': 1, 'sysadmin': True}


def change(settings, old, new):
    client = Transport(settings['hostname'], settings['port'], settings['ca'])
    status, result = client.request('PUT', '/api/v2.0/users/1/password', {'old_password': old, 'new_password': new}, credentials=('admin', old))
    require(status == 200, 'Harbor rejected the password change; API write is never blindly retried')
