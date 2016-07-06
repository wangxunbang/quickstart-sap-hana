suse= { "us-east-1":"ami-70f74418",
                        "us-west-2":"ami-3b0f420b",
                        "us-west-1":"ami-cbe3e88e",
                        "eu-west-1":"ami-30842747",
                        "ap-southeast-1":"ami-a4bd9af6",
                        "ap-northeast-1":"ami-69012b68",
                        "ap-southeast-2":"ami-41a5c77b",
                        "sa-east-1":"ami-ef8134f2",
                        "eu-central-1":"ami-423e085f"
                        }


suse = {     "us-east-1":"ami-b28fcbda",
                        "us-west-2":"ami-99f2aba9",
                        "us-west-1":"ami-b48891f1",
                        "eu-west-1":"ami-c9c448be",
                        "ap-southeast-1":"ami-d8be958a",
                        "ap-northeast-1":"ami-8cb8a68d",
                        "ap-southeast-2":"ami-810d79bb",
                        "sa-east-1":"ami-67912d7a",
                        "eu-central-1":"ami-ea0033f7"
                }


rhel = {"us-east-1":"ami-23ea0648",
                        "us-west-2":"ami-15e1df25",
                        "us-west-1":"ami-3311fa77",
                        "eu-west-1":"ami-99126fee",
                        "ap-southeast-1":"ami-a6d5eef4",
                        "ap-northeast-1":"ami-dce538dc",
                        "ap-southeast-2":"ami-a74c349d",
                        "sa-east-1":"ami-b3e666ae",
                        "eu-central-1" :"ami-4c073e51",
                }

m = {}
for k in suse:
    m[k] = {}

SUSEAMI = {}
for k in suse:
    m[k]["SUSE"] = suse[k]

RHELAMI = {}
for k in rhel:
    m[k]["RHEL"] = rhel[k]

print m
