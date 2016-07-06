'use strict';
var fs = require('fs');
var __ = require('underscore'); 

/**
 * Computes best AMZN amis for different instance types using AWS CLI.
 * AMIs are sorted by time and latest one is chosen.
 * Priority given to HVM GP2 ami over PV ami (when supported)
 *
 *
 * @param none
 * @returns JSON obj {"instancetype":"ami"} list
 */

var child_process = require('child_process');
var amiAMZN64HVM="amzn-ami-hvm-*x86_64-gp2"
var amiAMZN64PV="amzn-ami-pv-*x86_64-ebs"

if (!String.prototype.contains) {
    String.prototype.contains = function (arg) {
        return !!~this.indexOf(arg);
    };
}

function escapeRegExp(string) {
    return string.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}

function replaceAll(string, find, replace) {
  return string.replace(new RegExp(escapeRegExp(find), 'g'), replace);
}

function getRegions() {
  var cmd = "aws ec2 describe-regions"
  var regions = child_process.execSync(cmd, { encoding: 'utf8' });
  regions = JSON.parse(regions);
  return regions;
}

function getAMIbyName(name,region) {
  var cmd = "aws ec2 describe-images --filters \"Name=name,Values=AMI-PLACEHOLDER\" --region REGION-PLACEHOLDER";
  cmd = replaceAll(cmd,"AMI-PLACEHOLDER",name);
  cmd = replaceAll(cmd,"REGION-PLACEHOLDER",region);

  var ami = child_process.execSync(cmd, { encoding: 'utf8' });

  return JSON.parse(ami);
}

//amiregEx is amiAMZN64HVM or amiAMZN64PV
function getAMZNamis(amiregEx) {
  var amis = {};
  amis["AMI"] = {};
  var regions = getRegions();
  for (var v in regions.Regions) {
    var _region = (regions.Regions[v].RegionName);
    var ami = getAMIbyName(amiregEx,_region);
    var amiArray = Object.keys(ami.Images).map(function (key) {return ami.Images[key]});

    var amiArraySorted = amiArray.sort(CompareCreationDate);

    amis.AMI[_region] = {};
    //pick the first one, sorted by date
    amis.AMI[_region] = amiArraySorted[amiArraySorted.length-1].ImageId;
  }

  return amis.AMI;
}


function CompareCreationDate(a,b) {
	return Date.parse(a.CreationDate) - Date.parse(b.CreationDate) 
}

function getAMImatrix() {

	var instanceType = [];
	var data = {};

	data = {};
	data.family = 't2';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'm3';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'c3';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'c4';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'd2';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'r3';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'i2';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'hs1';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'm1';
	data.amiRegex = amiAMZN64PV;
	instanceType.push(data);

	data = {};
	data.family = 'c1';
	data.amiRegex = amiAMZN64PV;
	instanceType.push(data);

	data = {};
	data.family = 'cc2';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'm2';
	data.amiRegex = amiAMZN64PV;
	instanceType.push(data);

	data = {};
	data.family = 'cr1';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 'hi1';
	data.amiRegex = amiAMZN64HVM;
	instanceType.push(data);

	data = {};
	data.family = 't1';
	data.amiRegex = amiAMZN64PV;
	instanceType.push(data);

	return instanceType;

}

function instance2AMIRegEx() {

	var iTypes = [
				"t1.micro",
				"t2.micro",
				"t2.small",
				"t2.medium",
				"m1.small",
				"m1.medium",
				"m1.large",
				"m1.xlarge",
				"m2.xlarge",
				"m2.2xlarge",
				"m2.4xlarge",
				"m3.medium",
				"m3.large",
				"m3.xlarge",
				"m3.2xlarge",
				"c1.medium",
				"c1.xlarge",
				"c3.large",
				"c3.xlarge",
				"c3.2xlarge",
				"c3.4xlarge",
				"c3.8xlarge",
				"c4.large",
				"c4.xlarge",
				"c4.2xlarge",
				"c4.4xlarge",
				"c4.8xlarge",
				"r3.large",
				"r3.xlarge",
				"r3.2xlarge",
				"r3.4xlarge",
				"r3.8xlarge",
				"i2.xlarge",
				"i2.2xlarge",
				"i2.4xlarge",
				"i2.8xlarge",
				"hi1.4xlarge",
				"hs1.8xlarge",
				"cr1.8xlarge",
				"cc2.8xlarge",
				];

	var amiShort = [];
	amiShort[amiAMZN64HVM] = "hvm";
	amiShort[amiAMZN64PV] = "pv";

	var amiMatrix = getAMImatrix();
	var instanceType2AMIName = {};
	for (var i in iTypes) {
		var instance = iTypes[i];
		var family = instance.split('.')[0];
		var data = __.find(amiMatrix, function(v) {
			return v.family == family;
		});
		var amiRegex = data.amiRegex;	
		instanceType2AMIName[instance] = {"amiType": amiShort[amiRegex] };

	}

	var Region2AMZNami = {};
	var pvAMIs = getAMZNamis(amiAMZN64PV);
	var hvmAMIs = getAMZNamis(amiAMZN64HVM);
	var regions = getRegions();

	for (var v in regions.Regions) {
		var region = (regions.Regions[v].RegionName);
		Region2AMZNami[region] = {};
		Region2AMZNami[region]["pv"] = pvAMIs[region];
		Region2AMZNami[region]["hvm"] = hvmAMIs[region];
	}

	
	var out = {};
	out["Mappings"] = {};
	out["Mappings"]["Region2AMZNami"] = Region2AMZNami;
	out["Mappings"]["instanceType2AMIType"] = instanceType2AMIName;

	console.log(JSON.stringify(out, null, 4));


}

instance2AMIRegEx();
