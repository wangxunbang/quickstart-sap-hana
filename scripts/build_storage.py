import argparse
import os
import pprint
import subprocess
import json

aws_cmd = '/usr/local/bin/aws --debug'
ebs_attach_cmd = 'sh -x /root/install/create-attach-single-volume.sh '

def exe_cmd(cmd,cwd=None):
    #print 'DISABLED COMMAND ' + cmd
    return
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

def download_s3(s3path,odir):
    print 'Will download ' + s3path + ' To ' + odir
    cmd = aws_cmd
    cmd = cmd + ' s3 cp --recursive ' + s3path
    cmd = cmd + ' ' + odir
    if not os.path.exists(odir):
        os.makedirs(odir)
    print 'Executing ' + cmd
    output = exe_cmd(cmd)
    cmd = 'chmod 755 ' + odir + '/*.exe'
    output = exe_cmd(cmd)


# Note: We leave 1GB buffer

def stripe_hanashared_vol(drives):
    ##9.Created a new logical volume called lvhanaback with 2 stripes (Master Only)
    print 'Creating logical volumes for HANA Shared '
    size = 0
    for d in drives:
        # d['size'] = 488G etc
        size = size + int(d['size'].replace('G',''))
    buffer  = 1
    size = size - buffer
    sizeG = str(size) + 'G'

    device = drives[0]['device'].replace('/dev/s','/dev/xv')
    cmd = ' mkfs.xfs -f ' + device

    #cmd = 'lvcreate -n lvhanashared  '
    #cmd = cmd + ' -i ' + str(len(drives))
    #cmd = cmd + ' -I 256 ' + ' -L ' + sizeG + ' vghanashared'
    exe_cmd(cmd)
    print cmd

# Note: We leave 1GB buffer

def stripe_backup_vol(drives):
    ##9.Created a new logical volume called lvhanaback with 2 stripes (Master Only)
    print 'Creating logical volumes '
    size = 0
    for d in drives:
        # d['size'] = 488G etc
        size = size + int(d['size'].replace('G',''))
    buffer = 1
    size = size - buffer
    sizeG = str(size) + 'G'
    cmd = 'lvcreate -n lvhanaback  '
    cmd = cmd + ' -i ' + str(len(drives))
    cmd = cmd + ' -I 256 ' + ' -L ' + sizeG + ' vghanaback'
    exe_cmd(cmd)
    print cmd


#lvcreate -n lvhanadata -i 3 -I 256  -L ${mydataSize} vghana
#log "Creating hana log logical volume"
#lvcreate -n lvhanalog  -i 3 -I 256 -L ${mylogSize} vghana

def stripe_hanadatalog_vol(stripe,count):
    print 'Creating HANA data log logical volumes '
    size = 0
    for d in stripe:
        # d['size'] = 488G etc
        size = int(d['size'].replace('G',''))
        sizeG = str(size) + 'G'
        cmd = 'lvcreate -n  ' + d['logical_volume']
        cmd = cmd + ' -i ' + str(count)
        cmd = cmd + ' -I 256 ' + ' -L ' + sizeG + ' vghana'
        exe_cmd(cmd)
        print cmd


def short2long_drive(d):
	return d.replace('/dev/s','/dev/xv')

def create_backup_volgrp(drives):
    cmd = 'vgcreate vghanaback '
    for d in drives:
    	dev = d['device']
        cmd = cmd + ' ' + short2long_drive(d['device'])
    exe_cmd(cmd)
    print cmd

def create_hanashared_volgrp(drives):
    cmd = 'vgcreate vghanashared '
    for d in drives:
    	dev = d['device']
        cmd = cmd + ' ' + short2long_drive(d['device'])
    exe_cmd(cmd)
    print cmd


def create_hanadatalog_volgrp(drives):
    cmd = 'vgcreate vghana '
    for d in drives:
    	dev = d['device']
        cmd = cmd + ' ' + short2long_drive(d['device'])
    exe_cmd(cmd)
    print cmd

def init_drive(device):    
    cmd = 'pvcreate ' + device
    cmd = cmd.replace('/dev/sd','/dev/xvd')
    exe_cmd(cmd)
    print cmd


def create_attach_ebs(device,io_type,size,tag,piops = None):
    if piops == None:
        cmd = ebs_attach_cmd
        cmd = cmd + ':'.join([size,io_type,device,tag])
        exe_cmd(cmd)
        print cmd
        init_drive(device)
    else:
        cmd = ebs_attach_cmd
        cmd = cmd + ':'.join([size,io_type,str(piops),device,tag])
        exe_cmd(cmd)
        print cmd
        init_drive(device)

def create_attach_single_ebs(device,io_type,size,tag,piops = None):
    if piops == None:
        cmd = ebs_attach_cmd
        cmd = cmd + ':'.join([size,io_type,device,tag])
        exe_cmd(cmd)
        print cmd
    else:
        cmd = ebs_attach_cmd
        cmd = cmd + ':'.join([size,io_type,str(piops),device,tag])
        exe_cmd(cmd)
        print cmd


def get_backup_drives(config_json,hostcount,instance_type,storage_type):
    result = {}
    for idx,val in enumerate(config_json['backup']):
        if val['hostcount'] == hostcount:
            return val['storage']['master'][instance_type][storage_type]['drives']
    print 'ERROR: Unable to find get_backup_storage'
    return result


def main():
    parser = argparse.ArgumentParser(description='Build EBS storage config')
    parser.add_argument('-config', dest="config",metavar="FILE",required = True,
                              help='JSON containing master storage config')
    parser.add_argument('-ismaster', dest="ismaster",metavar="INT",required = True,
                              help='Is this master node or not ?')
    parser.add_argument('-hostcount', dest="hostcount",metavar="INT",required = True,
                              help='Total Hostcount?')
    parser.add_argument('-which', dest="which",metavar="STRING",required = True,
                              help='Which Storage? [backup,hana_data_log,shared,usr_sap,]')
    parser.add_argument('-instance_type', dest="instance_type",metavar="STRING",required = True,
                              help='Which instance_type?')
    parser.add_argument('-storage_type', dest="storage_type",metavar="STRING",required = True,
                              help='Which storage_type?')

    args = parser.parse_args()

    config = args.config
    ismaster = int(args.ismaster)
    hostcount = int(args.hostcount)
    which = args.which
    instance_type = args.instance_type
    storage_type = args.storage_type


    if not os.path.isfile(config):
        print 'Storage config file ' + config + ' Invalid!'
        print 'ERROR: Cannot build storage'
        return

    if ismaster != 1 and which == 'backup':
        print 'Backup storage valid only on HANA master'
        print 'WARNING: Did not build backup storage on worker'
        return

    if ismaster != 1 and which == 'shared':
        print 'Shared storage valid only on HANA master'
        print 'WARNING: Did not build shared storage on worker'
        return

    with open(config) as f:
        config_json = json.loads(f.read())

    if which == 'backup':
        drives = get_backup_drives(config_json,hostcount,instance_type,storage_type)
        for d in drives:
            device = d['device']
            io_type = storage_type
            size = d['size'].replace("G","")
            tag = 'SAP-HANA-Backup'
            create_attach_ebs(device,io_type,size,tag,None)
        create_backup_volgrp(drives)
        stripe_backup_vol(drives)
        return

    if which == 'hana_data_log':
        if ismaster == 1:
            drives = config_json['hana_data_log']['master'][instance_type][storage_type]['drives']
            stripe = config_json['hana_data_log']['master'][instance_type][storage_type]['stripe']
        else:
            drives = config_json['hana_data_log']['worker'][instance_type][storage_type]['drives']
            stripe = config_json['hana_data_log']['worker'][instance_type][storage_type]['stripe']
        for d in drives:
            device = d['device']
            io_type = storage_type
            piops = None
            if 'piops' in d:
                piops = d['piops']
            size = d['size'].replace("G","")
            tag = 'HANA-Data-Log'
            create_attach_ebs(device,io_type,size,tag,piops)
        create_hanadatalog_volgrp(drives)
        count = len(drives)
        stripe_hanadatalog_vol(stripe,count)
        return

    if which == 'shared':
        drives = config_json['shared']['master'][instance_type][storage_type]['drives']
        if len(drives) == 1:
	        for d in drives:
		            device = d['device']
		            io_type = storage_type
		            size = d['size'].replace("G","")
		            tag = 'SAP-HANA-Shared'
		            piops = None
		            if 'piops' in d:
		                piops = d['piops']
		            create_attach_single_ebs(device,io_type,size,tag,piops)
		            device = drives[0]['device'].replace('/dev/s','/dev/xv')
		            mkfs_cmd = 'mkfs.xfs -f ' + device
		            print mkfs_cmd
        else:
	        for d in drives:
	            device = d['device']
	            io_type = storage_type
	            size = d['size'].replace("G","")
	            tag = 'SAP-HANA-Shared'
	            piops = None
	            if 'piops' in d:
	                piops = d['piops']
	            create_attach_ebs(device,io_type,size,tag,piops)
	        create_hanashared_volgrp(drives)
	        stripe_hanashared_vol(drives)
        return

    if which == 'usr_sap':
        if ismaster == 1:
            drives = config_json['usr_sap']['master'][instance_type][storage_type]['drives']
        else:
            drives = config_json['usr_sap']['worker'][instance_type][storage_type]['drives']
        for d in drives:
            device = d['device']
            io_type = storage_type
            size = d['size'].replace("G","")
            tag = 'SAP-HANA-USR-SAP'
            piops = None
            if 'piops' in d:
                piops = d['piops']
            create_attach_ebs(device,io_type,size,tag,piops)
        return



if __name__ == "__main__":
    main()
