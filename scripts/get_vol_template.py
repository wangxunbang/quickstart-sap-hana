import argparse
import os
import pprint
import subprocess
import json
import getopt, sys
import json

def get_hana_data_log_config():
    instances = ["r3.8xlarge","r3.4xlarge","r3.2xlarge","c3.8xlarge"]
    logsizes = ["244G","244G","244G","244G"]
    datasizes = ["488G","488G","488G","488G"]
    ebs = ["gp2","io1"]
    config = {}
    for role in ["master","worker"]:
        config[role] = {}
        for index,instance in enumerate(instances):
            config[role][instance] = {}
            for e in ebs:
                config[role][instance][e] = {}
                config[role][instance][e]["volume_group"] = "vghana"
                config[role][instance][e]["stride"] = 256
                drives = []
                val = {}
                val["device"] = "/dev/sdb"
                val["size"] = "400G"
                if "io1" in e:
                    val["piops"] = 5000
                drives.append(val)
                val = {}
                val["device"] = "/dev/sdc"
                val["size"] = "400G"
                if "io1" in e:
                    val["piops"] = 5000
                drives.append(val)
                val = {}
                val["device"] = "/dev/sdd"
                val["size"] = "400G"
                if "io1" in e:
                    val["piops"] = 5000
                drives.append(val)
                config[role][instance][e]["drives"] = drives
                config[role][instance][e]["stripe"] = []
                val = {}
                val["size"] = logsizes[index]
                val["drive"] = "/hana/log"
                val["logical_volume"] = "lvhanalog"
                config[role][instance][e]["stripe"].append(val)
                val = {}
                val["size"] = datasizes[index]
                val["drive"] = "/hana/data"
                val["logical_volume"] = "lvhanadata"
                config[role][instance][e]["stripe"].append(val)
    return config


def get_usrsap():
    instances = ["r3.8xlarge","r3.4xlarge","r3.2xlarge","c3.8xlarge"]
    ebs = ["gp2"]
    usrsap = ["50G","50G","50G","50G"]
    config = {}
    for role in ["master","worker"]:
        config[role] = {}
        for index,instance in enumerate(instances):
            config[role][instance] = {}
            for e in ebs:
                config[role][instance][e] = {}
                drives = []
                val = {}
                val["device"] = "/dev/sds"
                val["size"] = usrsap[index]
                drives.append(val)
                config[role][instance][e]["drives"] = drives

    return config


def get_shared():
    instances = ["r3.8xlarge","r3.4xlarge","r3.2xlarge","c3.8xlarge"]
    ebs = ["gp2"]
    shared = ["50G","50G","50G","50G"]
    config = {}
    for role in ["master"]:
        config[role] = {}
        for index,instance in enumerate(instances):
            config[role][instance] = {}
            for e in ebs:
                config[role][instance][e] = {}
                drives = []
                val = {}
                val["device"] = "/dev/sde"
                val["size"] = shared[index]
                drives.append(val)
                config[role][instance][e]["drives"] = drives

    return config

def get_backup():
    instances = ["r3.8xlarge","r3.4xlarge","r3.2xlarge","c3.8xlarge"]
    ebs = ["gp2","st1"]
    shared = ["50G","50G","50G","50G"]
    config = {}
    for role in ["master"]:
        config[role] = {}
        for index,instance in enumerate(instances):
            config[role][instance] = {}
            for e in ebs:
                if "gp2" in e:
                    config[role][instance][e] = {}
                    drives = []
                    val = {}
                    val["device"] = "/dev/sdf"
                    val["size"] = shared[index]
                    drives.append(val)
                    val = {}
                    val["device"] = "/dev/sdg"
                    val["size"] = shared[index]
                    drives.append(val)
                    config[role][instance][e]["drives"] = drives
                if "st1" in e:
                    config[role][instance][e] = {}
                    drives = []
                    val = {}
                    val["device"] = "/dev/sdf"
                    val["size"] = shared[index]
                    drives.append(val)
                    config[role][instance][e]["drives"] = drives

    return config

def main():
    config = {}
    config["hana_data_log"] = get_hana_data_log_config()
    config["usr_sap"] = get_usrsap()
    config["shared"] = get_shared()
    config["backup"] = get_backup()

    print json.dumps(config, sort_keys=True,
                          indent=4, separators=(',', ': '))
    return




if __name__ == "__main__":
    main()
