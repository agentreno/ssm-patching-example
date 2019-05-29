# Data inputs
data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnet_ids" "default" {
    vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_iam_policy" "ssm_ec2" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Test instance for patching
resource "aws_instance" "patch_target" {
    ami = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    subnet_id = "${element(data.aws_subnet_ids.default.ids, 0)}"
    iam_instance_profile = "${aws_iam_instance_profile.default.name}"

    key_name = "${var.ec2_key_pair_name}"

    tags {
        Name = "patch-test-box"
        PatchGroup = "${aws_ssm_patch_group.default.id}"
    }
}

resource "aws_iam_role" "instance" {
    name = "patch-test-instance-role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com","ssm.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "instance_attachment" {
    role = "${aws_iam_role.instance.name}"
    policy_arn = "${data.aws_iam_policy.ssm_ec2.arn}"
}

resource "aws_iam_instance_profile" "default" {
    name = "patch-test-profile"
    role = "${aws_iam_role.instance.name}"
}
