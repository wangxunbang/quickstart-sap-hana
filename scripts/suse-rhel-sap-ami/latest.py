import argparse
import subprocess
import json
import dateutil.parser

aws_cmd = '/usr/local/bin/aws '

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

def get_creationdate(data):
	oldest = '2001-10-11T17:17:47.000Z'
	name = data['Name']
	if 'sapcal' in name:
		return  dateutil.parser.parse(oldest)
	if 'rightscale' in name:
		return  dateutil.parser.parse(oldest)
	return  dateutil.parser.parse(data['CreationDate'])

def filter_suse_12(data):
	oldest = '2001-10-11T17:17:47.000Z'
	name = data['Name']
	if 'sapcal' in name:
		return  dateutil.parser.parse(oldest)
	if 'rightscale' in name:
		return  dateutil.parser.parse(oldest)
	if "sp1" in name:
		return  dateutil.parser.parse(oldest)
	return  dateutil.parser.parse(data['CreationDate'])


def get_latest_ami():

	AMI = {}
	with open("regions.txt") as f:
		regions = f.read().split('\n')
		del regions[-1]
		amis = [
                "SUSE",
                "RHEL",
                "SUSE 12",
                "SUSE 12 SP1",
                "RHEL 6",
                "RHEL 7"
            ]
        aminames = {}
        owners = {}
        #suse-sles-11-sp3-v20150127-hvm-ssd-x86_64
        aminames["SUSE"] = "suse-sles-11-sp3*" 
        aminames["SUSE 12"] = "suse-sles-12*" 
        aminames["SUSE 12 SP1"] = "suse-sles-12-sp1*" 
        aminames["RHEL"] = "RHEL-6.6_HVM*"
        aminames["RHEL 6"] = "RHEL-6.6_HVM*"
        aminames["RHEL 7"] = "RHEL-7.1_HVM*"

        owners["SUSE"] = "013907871322"
        owners["SUSE 12"] = "013907871322"
        owners["SUSE 12 SP1"] = "013907871322"
        owners["RHEL"] = "309956199498"
        owners["RHEL 6"] = "309956199498"
        owners["RHEL 7"] = "309956199498"

	for r in regions:
		ami_type = "hvm"
		region = r
		AMI[region] = {}
		for ami in amis:
			ami_name = aminames[ami]
			owner = owners[ami]
			cmd = aws_cmd + " ec2 describe-images --filters \"Name=name,Values=AMI-PLACEHOLDER\" \"Name=virtualization-type,Values=VTYPE-PLACEHOLDER\" --owners OWNER-PLACEHOLDER --region REGION-PLACEHOLDER"
			cmd = cmd.replace('AMI-PLACEHOLDER',ami_name)
			cmd = cmd.replace('VTYPE-PLACEHOLDER',ami_type)
			cmd = cmd.replace('REGION-PLACEHOLDER',region)
			cmd = cmd.replace('OWNER-PLACEHOLDER',owner)
			output = exe_cmd(cmd)
			images = output['out']
			val = json.loads(images)
			images =  val['Images']
			if ami == "SUSE 12":
				sorted_images = sorted(images,key = filter_suse_12,reverse=True)
			else:
				sorted_images = sorted(images,key = get_creationdate,reverse=True)
			#print cmd
			latest_ami = sorted_images[0]['ImageId']
			AMI[region][ami] = latest_ami
			#print(json.dumps(AMI, sort_keys=True))

	print(json.dumps(AMI, sort_keys=True))




def main():
    parser = argparse.ArgumentParser(description='Find latest RHEL AMI')
    parser.add_argument('-v', dest="version",metavar="VERSION",required = True,
                              help='RHEL Version')
    parser.add_argument('-r', dest="region",metavar="REGION",required = True,
                              help='REGION to query AMI')
    parser.add_argument('-t', dest="type",metavar="AMI_TYPE",required = True,
                              help='AMI Type (paravirtual,hvm)')

    get_latest_ami()
    return

    args = parser.parse_args()
    version = args.version
    region = args.region
    ami_type = args.type

    ami_name = 'RHEL-'+ version + "*" + "-x86_64*";

    cmd = aws_cmd + " ec2 describe-images --filters \"Name=name,Values=AMI-PLACEHOLDER\" \"Name=virtualization-type,Values=VTYPE-PLACEHOLDER\" --owners 309956199498 --region REGION-PLACEHOLDER"
    cmd = cmd.replace('AMI-PLACEHOLDER',ami_name)
    cmd = cmd.replace('VTYPE-PLACEHOLDER',ami_type)
    cmd = cmd.replace('REGION-PLACEHOLDER',region)

    output = exe_cmd(cmd)
    images = output['out']
    val = json.loads(images)
    images =  val['Images']
    sorted_images = sorted(images,key = get_creationdate,reverse=True)
    print sorted_images[0]['ImageId']



if __name__ == "__main__":
    main()
