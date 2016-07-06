import argparse
import os
import pprint
import subprocess
import json

aws_cmd = '/usr/local/bin/aws --debug'

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


def main():
    parser = argparse.ArgumentParser(description='Process AdvancedOptions ')
    try:
        args = parser.parse_args()
        read_config()
        advanced = os.environ['ADVANCED_JSON'].rstrip()
        cmd = 'curl -s http://169.254.169.254/latest/dynamic/instance-identity/document'
        output = exe_cmd(cmd)
        mydoc = json.loads(output['out'])
        myid = mydoc['instanceId']
        cmd = '/bin/hostname'
        output = exe_cmd(cmd)
        myhostname = output['out'].rstrip()
        stack = os.environ['MyStackId'].rstrip()
        options = {}
        if os.path.isfile(advanced):
            with open(advanced) as f:
                options = json.load(f)
        if 'CreateAMI' in options:
            # Create AMI at the end of deployment!
            if options['CreateAMI'] == 'True':
                cmd = aws_cmd
                cmd = cmd + '  ec2 create-image '
                cmd = cmd + ' --instance-id ' + myid
                name = "SAP HANA AMI of " + myhostname
                cmd = cmd + ' --name ' + '"' + name + '"'
                desc = "AMI of " + myhostname + " Created via " + stack
                cmd = cmd + ' --description ' + '"' + desc + '"'
                cmd = cmd + ' --no-reboot '
                cmd = cmd +  ' --region ' + os.environ['REGION'].rstrip()
                print 'executing ' + cmd 
                output = exe_cmd(cmd)
    except Exception:
        print 'Unknown exception while processing advanced options'
        print 'Ignoring all advanced options'
        print Exception


if __name__ == "__main__":
    main()
