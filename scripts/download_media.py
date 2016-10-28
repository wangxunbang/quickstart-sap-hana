import argparse
import os
import pprint
import subprocess
import json

aws_cmd = '/usr/local/bin/aws'
extract_cmd = "/usr/bin/unrar x exe_file extract_dir"
find_cmd = "/usr/bin/find compressed_dir  -name '*.exe' "


def exe_cmd(cmd,cwd=None):
    proc = subprocess.Popen([cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, cwd=cwd)
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

def download_s3(s3path,odir):
    print 'Will download ' + s3path + ' To ' + odir
    cmd = aws_cmd
    cmd = cmd + ' s3 sync ' + s3path
    cmd = cmd + ' ' + odir
    if not os.path.exists(odir):
        os.makedirs(odir)
    print 'Executing ' + cmd
    output = exe_cmd(cmd)
    cmd = 'chmod 755 ' + odir + '/*.exe'
    output = exe_cmd(cmd)

def main():
    parser = argparse.ArgumentParser(description='Download HANA Media (No extraction)')
    parser.add_argument('-o', dest="odir",metavar="DIR",required = True,
                              help='DIR to download Media')
    args = parser.parse_args()
    odir = args.odir
    read_config()
    params = get_mystack_params()
    s3path = params['HANAInstallMedia']
#    compressed_dir = odir + '/' + 'compressed'
    compressed_dir = odir + 'compressed'
    download_s3(s3path,compressed_dir)

if __name__ == "__main__":
    main()
