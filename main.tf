
# Enter users name below to populate within this file.
variable "friendlyName" { default = "YOUR_NAME_HERE" }

variable "aws_access_key" {default = "XXXXXXXXXXXXXXXXXXXXXXXXXX"}
variable "aws_secret_key" {default = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}

variable "myWorkloadTag" { default = "Session01-HelloWorld" }
variable "aws_region" {default = "ap-southeast-2"}

provider "aws" {
#	access_key = "${var.aws_access_key}"
#	secret_key = "${var.aws_secret_key}"
	profile = "sandbox"
	region	= "${var.aws_region}"
}

data "aws_ami" "winSvr2019" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Amazon
}

resource "aws_vpc" "myVpc" {
	cidr_block = "192.168.0.0/20"
	tags = {
		Name = "${var.friendlyName}_VPC"
		Workload = "${var.myWorkloadTag}"
	}

}

resource "aws_subnet" "myVpc-sn01" {
	vpc_id = "${aws_vpc.myVpc.id}"
	cidr_block = "192.168.0.0/24"
	tags = {
		Name = "myVpc-sn01"
		Worklodad = "${var.myWorkloadTag}"
	}
	
}

resource "aws_internet_gateway" "myVpcGw" {
	vpc_id = "${aws_vpc.myVpc.id}"
	tags = {
		Name = "${var.friendlyName}_internet_gateway"
		Worklodad = "${var.myWorkloadTag}"
	}

}

resource "aws_route_table" "route_table" {
	vpc_id = "${aws_vpc.myVpc.id}"
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.myVpcGw.id}"
	}
	tags = {
		Name = "${var.friendlyName}_route_table"
		Worklodad = "${var.myWorkloadTag}"
	}

}

resource "aws_route_table_association" "myVpcRta" {
	subnet_id = "${aws_subnet.myVpc-sn01.id}"
	route_table_id = "${aws_route_table.route_table.id}"
}

resource "aws_security_group" "myVpcSg-Allow-HTTPS_RDP" {
	name = "Allow Inbound"
	description = "The rule to do what the name says"
	vpc_id = "${aws_vpc.myVpc.id}"
	ingress {
		from_port = 443
		to_port = 443
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 3389
		to_port = 3389
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		Name = "${var.friendlyName}_security_group"
		Worklodad = "${var.myWorkloadTag}"
	}
}

resource "aws_key_pair" "myKeyPair" {
	key_name = "${var.friendlyName}_Key"
	public_key = "${file("./resources/aws_key_pair.pub")}"
}

resource "aws_instance" "test_server" {
	ami = "${data.aws_ami.winSvr2019.id}"
	instance_type = "t2.small"
	key_name = "${aws_key_pair.myKeyPair.id}"
	subnet_id = "${aws_subnet.myVpc-sn01.id}"
	vpc_security_group_ids = ["${aws_security_group.myVpcSg-Allow-HTTPS_RDP.id}"]
	associate_public_ip_address = true
	get_password_data = true
	user_data = "${file("./resources/user_data_bootstrap.txt")}"
	tags = {
		Name = "${var.friendlyName}_ec2_instance"
		Worklodad = "${var.myWorkloadTag}"
	}
	
}

output "Connect_IP_Address" {
  value = "${aws_instance.test_server.public_ip}"
}

output "Connect_Username" {
  value = "Administrator"
}

output "Connect_Password" {
  value = "${rsadecrypt(aws_instance.test_server.password_data, file("./resources/aws_key_pair"))}"
}
