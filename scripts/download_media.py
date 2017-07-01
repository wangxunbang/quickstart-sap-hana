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
    read_config()
    stackid = os.environ['MyStackId'].rstrip()
    cmd = aws_cmd
    cmd = cmd + ' cloudformation describe-stacks --stack-name '
    cmd = cmd + stackid
    cmd = cmd +  ' --region ' + os.environ['REGION'].rstrip()
    new_env=os.environ.copy()
    for key,value in new_env.iteritems():
        new_env[key]=value.strip()
    proc = subprocess.Popen([cmd], env=new_env, stdout=subprocess.PIPE, shell=True)
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
    new_env=os.environ.copy()
    for key,value in new_env.iteritems():
        new_env[key]=value.strip()
    if not os.path.exists(odir):
        os.makedirs(odir)
    s3bucket = s3path.split('s3://')[1].split('/')[0]
    cmd = aws_cmd + ' s3api get-bucket-location --bucket ' + s3bucket + " | grep -Po '(?" + '<="LocationConstraint": ")[^"]*'+ "'"
    s3bucketregion = subprocess.Popen([cmd], env=new_env, stdout=subprocess.PIPE, shell=True)
    s3bucketregion = s3bucketregion.stdout.read().rstrip()
    print 'Will download HANA media from ' + s3path + ' To ' + odir
    cmd = aws_cmd
    cmd = cmd + ' s3 sync ' + s3path
    if s3bucketregion == "null" or s3bucketregion == "":
        cmd = cmd + ' ' + odir
    else:
        cmd = cmd + ' ' + odir + ' --region ' + s3bucketregion
    if not os.path.exists(odir):
        os.makedirs(odir)
    print 'Executing ' + cmd
    output = subprocess.Popen([cmd], env=new_env, stdout=subprocess.PIPE, shell=True)
    (out, err) = output.communicate()
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
