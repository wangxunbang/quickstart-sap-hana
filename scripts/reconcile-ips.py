#!/usr/local/aws/bin/python


# ------------------------------------------------------------------
#     Code to extract IP<->Hostname mapping into /etc/hostname
#     Use this when all hosts have their IP in dynamodb table
#     Make sure all nodes have their IPs populated!
# ------------------------------------------------------------------

import getopt, sys
import os
import subprocess
import json
import pprint
from pprint import pprint


def usage():
    print 'reconcile IPs from DynamoDB table for all HANA hosts'
    print 'reconcile-ips.py -c <HostCount> -n <TableName>'
    sys.exit(2)

def main():
    if len (sys.argv) <= 2:
        usage()
        sys.exit(2)


    try:
        opts, args = getopt.getopt(sys.argv[1:], "hc:n:", ["help"])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err) # will print something like "option -a not recognized"
        usage()
        sys.exit(2)
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-c"):
            hostcount = a
        elif o in ("-n"):
            tablename = a
        else:
            assert False, "unhandled option"

    command = ['bash', '-c', 'source /root/install/config.sh && env']
    proc = subprocess.Popen(command, stdout = subprocess.PIPE)
    for line in proc.stdout:
      (key, _, value) = line.partition("=")
      os.environ[key] = value
    proc.communicate()
    tablename=os.environ["TABLE_NAME"].rstrip()
    print tablename


    # Wait until all HANA nodes have populated their IPs
    cmd ='/bin/sh /root/install/cluster-watch-engine.sh '
    cmd = cmd + ' -n ' + tablename + ' -w ' + '"PRE_INSTALL_COMPLETE=' + str(hostcount) + '"'
    print "Executing ",cmd
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    (output, err) = p.communicate()
    p_status = p.wait()
    print output

    # Populate all IPs to hostname
    cmd ='/bin/sh /root/install/cluster-watch-engine.sh ' + ' -n ' + tablename + ' -p'
    print "Populating IPs via ",cmd
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    (output, err) = p.communicate()
    p_status = p.wait()
    ip_tables = json.loads(output)

    hostname_file = "/etc/hosts"
    for table in ip_tables['Items']:
        try:
            ip = table['PrivateIpAddress']['S']
            domain = table['DomainName']['S']
            hostname = table['MyHostname']['S']
            print ip + ':' + hostname
            with open(hostname_file, "a") as f:
                f.write(ip + ' ' + hostname + '.' + domain + ' ' + hostname + '\n')
        except Exception:
            print 'Error: ip or hostname not populated in db!'
            pass


if __name__ == "__main__":
    main()
