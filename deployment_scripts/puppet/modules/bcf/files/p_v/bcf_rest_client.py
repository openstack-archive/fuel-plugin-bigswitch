import argparse
import functools
import httplib
import json
import traceback
import sys
import yaml

HASH_HEADER = 'BCF-SETUP'
BCF_CONTROLLER_PORT = 8443
ANY = 'any'
ELEMENT_EXISTS = "List element already exists"
LOG_FILE = '/var/log/bsn.log'


def debug_func(*dargs, **dkwargs):
    def wrapper(func):
        @functools.wraps(func)
        def inner(*args, **kwargs):
            with open(LOG_FILE, "a") as log_file:
                log_file.write(
                    "Function %s called with args [%s], kwargs %s\n" % (
                        func.func_name, ','.join(
                            ["%s=%s" % (x, y)  # this code gets the names of args
                             for (x, y) in zip(func.func_code.co_varnames, args)]
                        ), kwargs
                    )
                )
            ret = func(*args, **kwargs)
            if dkwargs.get('log_return'):
                with open(LOG_FILE, "a") as log_file:
                    log_file.write("Function %s returning with value %s\n"
                                   % (func.func_name, ret))
            return ret
        return inner
    # this first case handles when the decorator is called without args
    # (e.g. @debug_func) and the second is for when an arg is passed
    # (e.g. @debug_func(log_return=True)
    if dargs and callable(dargs[0]):
        return wrapper(dargs[0])
    return wrapper


class NodeConfig(object):
    def __init__(self, yaml_file='/etc/astute.yaml'):
        self.bridge_vlan_map = {}

        with open(yaml_file, 'r') as myfile:
            yaml_cfg = myfile.read()
        try:
            node_config = yaml.load(yaml_cfg)
        except Exception as e:
            with open(LOG_FILE, "a") as log_file:
                log_file.write("Error parsing node yaml file:\n%(e)s\n"
                       % {'e': e})
            return None
        trans = node_config['network_scheme']['transformations']
        # get the bridge where bond is connected
        for tran in trans:
            if (tran['action'] != 'add-patch'):
                continue
            if ('br-prv' not in tran['bridges']):
                continue
            bridges = list(tran['bridges'])
            bridges.remove('br-prv')
            bond_bridge = bridges[0]
            break

        # Get bond name
        for tran in trans:
            if (tran['action'] != 'add-bond'):
                continue
            if (bond_bridge != tran.get('bridge')):
                continue
            bond_name = tran['name']
            break

        for tran in trans:
            if (tran['action'] == 'add-port' and
                    bond_name in tran['name'] and
                    '.' in tran['name']):
                self.bridge_vlan_map[tran['bridge']] = (
                    int(tran['name'].split('.')[1]))

    @debug_func(log_return=True)
    def get_bridge_vlan_str(self):
        return ["%s:%d" % (bridge.split('-')[1],vlan)
                for bridge, vlan in self.bridge_vlan_map.items()]

class RestLib(object):
    @staticmethod
    def request(url, prefix="/api/v1/data/controller/", method='GET',
                data='', hashPath=None, host="127.0.0.1:8443", cookie=None):
        headers = {'Content-type': 'application/json'}

        if cookie:
            headers['Cookie'] = 'session_cookie=%s' % cookie

        if hashPath:
            headers[HASH_HEADER] = hashPath

        connection = httplib.HTTPSConnection(host)

        try:
            connection.request(method, prefix + url, data, headers)
            response = connection.getresponse()
            ret = (response.status, response.reason, response.read(),
                   response.getheader(HASH_HEADER))
            with open(LOG_FILE, "a") as log_file:
                log_file.write('Controller REQUEST: %s %s:body=%r\n' %
                              (method, host + prefix + url, data))
                log_file.write('Controller RESPONSE: status=%d reason=%r,'
                               'data=%r, hash=%r\n' % ret)
            return ret
        except Exception as e:
            raise Exception("Controller REQUEST exception: %s" % e)

    @staticmethod
    def get(cookie, url, server, port, hashPath=None):
        host = "%s:%d" % (server, port)
        return RestLib.request(url, hashPath=hashPath, host=host,
                               cookie=cookie)

    @staticmethod
    def post(cookie, url, server, port, data, hashPath=None):
        host = "%s:%d" % (server, port)
        return RestLib.request(url, method='POST', hashPath=hashPath,
                               host=host, data=data, cookie=cookie)

    @staticmethod
    def patch(cookie, url, server, port, data, hashPath=None):
        host = "%s:%d" % (server, port)
        return RestLib.request(url, method='PATCH', hashPath=hashPath,
                               host=host, data=data, cookie=cookie)

    @staticmethod
    def put(cookie, url, server, port, data, hashPath=None):
        host = "%s:%d" % (server, port)
        return RestLib.request(url, method='PUT', hashPath=hashPath,
                               host=host, data=data, cookie=cookie)

    @staticmethod
    def delete(cookie, url, server, port, hashPath=None):
        host = "%s:%d" % (server, port)
        return RestLib.request(url, method='DELETE', hashPath=hashPath,
                               host=host, cookie=cookie)

    @staticmethod
    def auth_bcf(server, username, password, port=BCF_CONTROLLER_PORT):
        login = {"user": username, "password": password}
        host = "%s:%d" % (server, port)
        ret = RestLib.request("/api/v1/auth/login", prefix='',
                              method='POST', data=json.dumps(login),
                              host=host)
        session = json.loads(ret[2])
        if ret[0] != 200:
            raise Exception(ret)
        if ("session_cookie" not in session):
            raise Exception("Failed to authenticate: session cookie not set")
        return session["session_cookie"]

    @staticmethod
    @debug_func
    def logout_bcf(cookie, server, port=BCF_CONTROLLER_PORT):
        url = "core/aaa/session[auth-token=\"%s\"]" % cookie
        ret = RestLib.delete(cookie, url, server, port)
        return ret

    @staticmethod
    @debug_func(log_return=True)
    def get_active_bcf_controller(servers, username, password,
                                  port=BCF_CONTROLLER_PORT):
        for server in servers:
            try:
                cookie = RestLib.auth_bcf(server, username, password, port)
                url = 'core/controller/role'
                res = RestLib.get(cookie, url, server, port)[2]
                if 'active' in res:
                    return server, cookie
            except Exception:
                continue
        return None, None

    @staticmethod
    @debug_func(log_return=True)
    def get_os_mgmt_segments(server, cookie, tenant,
                             port=BCF_CONTROLLER_PORT):
        url = (r'''applications/bcf/info/endpoint-manager/segment'''
               '''[tenant="%(tenant)s"]''' %
               {'tenant': tenant})
        ret = RestLib.get(cookie, url, server, port)
        if ret[0] != 200:
            raise Exception(ret)
        res = json.loads(ret[2])
        segments = []
        for segment in res:
            # 'management' or 'Management' segment does not matter
            segments.append(segment['name'].lower())
        return segments

    @staticmethod
    @debug_func(log_return=True)
    def program_segment_and_membership_rule(
        server, cookie, tenant, segment, internal_port, vlan,
        port=BCF_CONTROLLER_PORT):

        existing_segments = RestLib.get_os_mgmt_segments(
            server, cookie, tenant, port)
        if segment not in existing_segments:
            with open(LOG_FILE, "a") as log_file:
                msg = (r'''Warning: BCF controller does not have tenant '''
                       '''%(tenant)s segment %(segment)s\n''' %
                       {'tenant': tenant, 'segment': segment})
                log_file.write(msg)

            segment_url = (
                r'''applications/bcf/tenant[name="%(tenant)s"]/segment''' %
                {'tenant': tenant})
            segment_data = {"name": segment}
            try:
                ret = RestLib.post(cookie, segment_url, server, port,
                                   json.dumps(segment_data))
            except Exception:
                ret = RestLib.patch(cookie, segment_url, server, port,
                                    json.dumps(segment_data))
            if ret[0] != 204:
                if (ret[0] != 409 or
                    ELEMENT_EXISTS not in ret[2]):
                    raise Exception(ret)

        intf_rule_url = (r'''applications/bcf/tenant[name="%(tenant)s"]/'''
                         '''segment[name="%(segment)s"]/'''
                         '''switch-port-membership-rule''' %
                         {'tenant': tenant,
                          'segment': segment})
        rule_data = {"interface": ANY, "switch": ANY, "vlan": vlan}
        try:
            ret = RestLib.post(cookie, intf_rule_url, server, port,
                               json.dumps(rule_data))
        except Exception:
            ret = RestLib.patch(cookie, intf_rule_url, server, port,
                                json.dumps(rule_data))
        if ret[0] != 204:
            if (ret[0] != 409 or
                ELEMENT_EXISTS not in ret[2]):
                raise Exception(ret)

        pg_rule_url = (r'''applications/bcf/tenant[name="%(tenant)s"]/'''
                       '''segment[name="%(segment)s"]/'''
                       '''interface-group-membership-rule''' %
                       {'tenant': tenant,
                        'segment': segment})
        rule_data = {"interface-group": ANY, "vlan": vlan}
        try:
            ret = RestLib.post(cookie, pg_rule_url, server, port,
                               json.dumps(rule_data))
        except Exception:
            ret = RestLib.patch(cookie, pg_rule_url, server, port,
                                json.dumps(rule_data))
        if ret[0] != 204:
            if (ret[0] != 409 or
                ELEMENT_EXISTS not in ret[2]):
                raise Exception(ret)

        specific_rule_url = (r'''applications/bcf/tenant[name="%(tenant)s"]/'''
                             '''segment[name="%(segment)s"]/'''
                             '''switch-port-membership-rule''' %
                             {'tenant': tenant,
                              'segment': segment})
        rule_data = {"interface": internal_port, "switch": ANY, "vlan": -1}
        try:
            ret = RestLib.post(cookie, specific_rule_url, server, port,
                               json.dumps(rule_data))
        except Exception:
            ret = RestLib.patch(cookie, specific_rule_url, server, port,
                                json.dumps(rule_data))
        if ret[0] != 204:
            if (ret[0] != 409 or
                ELEMENT_EXISTS not in ret[2]):
                raise Exception(ret)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-u", "--username", required=True,
                        help="username for bcf controller")
    parser.add_argument("-p", "--password", required=True,
                        help="password for bcf controller")
    parser.add_argument("-c", "--controllers", required=True,
                        help="ip addresses of controller cluster "
                        "separated by ,")
    parser.add_argument("-m", "--management-tenant", required=True,
                        help="Openstack management tenant.")
    parser.add_argument("-f", "--fuel-cluster-id", required=True,
                        help="The custer id of the fuel environment")
    args = parser.parse_args()

    ctrls = args.controllers.split(',')
    try:
        nodeCfg = NodeConfig()
        segments = nodeCfg.get_bridge_vlan_str()
        active_server, cookie = RestLib.get_active_bcf_controller(
            ctrls, args.username, args.password,
            port=BCF_CONTROLLER_PORT)
        for segment in segments:
            segment_name, vlan = segment.split(':')
            internal_port = "%s%s" % (segment_name[:3], args.fuel_cluster_id)
            seg_vlan = int(vlan)
            RestLib.program_segment_and_membership_rule(
                active_server, cookie, args.management_tenant,
                segment_name, internal_port, seg_vlan)

        sys.exit(0)
    except Exception as e:
        err = traceback.format_exc()
        with open(LOG_FILE, "a") as log_file:
            log_file.write('bcf_rest_client exception: %s\n' % err)
        sys.exit(-1)
