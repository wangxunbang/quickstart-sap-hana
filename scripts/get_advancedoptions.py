import argparse
import os
import pprint
import subprocess
import json
import getopt, sys

aws_cmd = '/usr/local/bin/aws --debug'
config_file = '/root/install/config.sh'

def exe_cmd(cmd,cwd=None):
    if cwd == None:
        proc = subprocess.Popen([cmd], stdout=subprocess.PIPE, shell=True)
        proc.wait()
        (out, err) = proc.communicate()
        output = {}
        output['out'] = out
        output['err'] = err
        return output
    else:
        proc = subprocess.Popen([cmd], stdout=subprocess.PIPE, shell=True,cwd=cwd)
        proc.wait()
        (out, err) = proc.communicate()
        output = {}
        output['out'] = out
        output['err'] = err
        return output

def read_config():
    command = ['bash', '-c', 'source /root/install/config.sh && env']
    proc = subprocess.Popen(command, stdout = subprocess.PIPE)
    for line in proc.stdout:
        (key, _, value) = line.partition("=")
        os.environ[key] = value
    proc.communicate()

def get_mystack_params():
    stackid = os.environ['MyStackId'].rstrip()
    cmd = aws_cmd
    cmd = cmd + ' cloudformation describe-stacks --stack-name '
    cmd = cmd + stackid
    cmd = cmd +  ' --region ' + os.environ['REGION'].rstrip()
    proc = subprocess.Popen([cmd], stdout=subprocess.PIPE, shell=True)
    proc.wait()
    (out, err) = proc.communicate()
    out_json = json.loads(out)
    params = out_json['Stacks'][0]['Parameters']
    input = {}
    for p in params:
        key = p['ParameterKey']
        val = p['ParameterValue']
        input[key] = val
    return input


def get_options(json_file):
    options = {}
    if os.path.isfile(json_file):
        with open(json_file) as f:
            options = json.load(f)
    return options

def set_advancedconfig(s3path,odir):
    print 'Will download ' + s3path + ' To ' + odir
    cmd = aws_cmd
    cmd = cmd + ' s3 cp  ' + s3path
    cmd = cmd + ' ' + odir
    if not os.path.exists(odir):
        os.makedirs(odir)
    print 'Executing ' + cmd
    output = exe_cmd(cmd)
    json_file = os.path.basename(s3path)
    options = get_options(odir + '/' + json_file)
    print 'Advanced Options:'
    print options
    with open(config_file,'a') as f:
        json_export = 'export ADVANCED_JSON='
        json_export = json_export + odir + '/' + json_file
        f.write(json_export + '\n')
        print json_export
        if 'CreateAMI' in options:
            if options['CreateAMI'] == 'True':
                json_export = 'export CREATE_AMI=True'
            else:
                json_export = 'export CREATE_AMI=False'
            f.write(json_export + '\n')
            print json_export
        if 'InstallHANA' in options:
            if options['InstallHANA'] == 'Yes':
                json_export = 'export INSTALL_HANA=Yes'
            else:
                json_export = 'export INSTALL_HANA=No'
            f.write(json_export + '\n')
            print json_export

        if 'DebugDeployment' in options:
            if options['DebugDeployment'] == 'True':
                json_export = 'export DEBUG_DEPLOYMENT=True'
            else:
                json_export = 'export DEBUG_DEPLOYMENT=False'
            f.write(json_export + '\n')
            print json_export


def main():
    parser = argparse.ArgumentParser(description='Download Custom JSON')
    parser.add_argument('-o', dest="odir",metavar="DIR",required = True,
                              help='DIR to download custom JSON')
    args = parser.parse_args()
    odir = args.odir
    read_config()
    params = get_mystack_params()
    try:
        if 'AdvancedOptions' in params:
            s3path = params['AdvancedOptions']
            set_advancedconfig(s3path,odir)
        else:
            print 'Advanced JSON not needed'
    except Exception:
        print 'Error: Unable to download custom JSON!'
        pass

if __name__ == "__main__":
    main()
