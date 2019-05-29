# IAM role for SSM
resource "aws_iam_role" "ssm_maintenance_role" {
    name = "patch-test-ssm-maintenance-role"
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

resource "aws_iam_role_policy_attachment" "ssm_attachment" {
    role = "${aws_iam_role.ssm_maintenance_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

# SSM Resources
resource "aws_ssm_patch_baseline" "baseline" {
    name = "patch-test-baseline"
    description = "Prototype baseline for SSM automated patching"
    operating_system = "UBUNTU"

    # The compliance priority if this rule isn't met
    approved_patches_compliance_level = "HIGH"

    
    approval_rule {
        approve_after_days = 0

        patch_filter {
            key = "PRIORITY"
            values = ["Required", "Important", "Standard"]
        }
    }
}

resource "aws_ssm_patch_group" "default" {
    baseline_id = "${aws_ssm_patch_baseline.baseline.id}"
    patch_group = "patch-test-group"
}

resource "aws_ssm_maintenance_window" "default" {
    name = "patch-test-window"

    # Every Saturday morning at 6am
    # https://docs.aws.amazon.com/systems-manager/latest/userguide/reference-cron-and-rate-expressions.html
    #schedule = "cron(0 6 * * SAT *)"

    # Every two hours
    schedule = "cron(0 0/2 * * ? *)"

    duration = 2
    cutoff = 1
}

resource "aws_ssm_maintenance_window_target" "default" {
    window_id = "${aws_ssm_maintenance_window.default.id}"
    resource_type = "INSTANCE"

    targets {
        key = "tag:PatchGroup"
        values = ["${aws_ssm_patch_group.default.id}"]
    }
}

resource "aws_ssm_maintenance_window_task" "scan" {
    window_id = "${aws_ssm_maintenance_window.default.id}"
    task_type = "RUN_COMMAND"
    task_arn = "AWS-RunPatchBaseline"
    priority = 1
    service_role_arn = "${aws_iam_role.ssm_maintenance_role.arn}"
    max_concurrency = 1
    max_errors = 1

    targets {
        key = "WindowTargetIds"
        values = ["${aws_ssm_maintenance_window_target.default.id}"]
    }

    task_parameters {
        name = "Operation"
        values = ["Scan"]
    }

    logging_info {
        s3_bucket_name = "${var.s3_logging_bucket_name}"
        s3_region = "${var.region}"
    }
}

resource "aws_ssm_maintenance_window_task" "install" {
    window_id = "${aws_ssm_maintenance_window.default.id}"
    task_type = "RUN_COMMAND"
    task_arn = "AWS-RunPatchBaseline"
    priority = 1
    service_role_arn = "${aws_iam_role.ssm_maintenance_role.arn}"
    max_concurrency = 1
    max_errors = 1

    targets {
        key = "WindowTargetIds"
        values = ["${aws_ssm_maintenance_window_target.default.id}"]
    }

    task_parameters {
        name = "Operation"
        values = ["Install"]
    }

    logging_info {
        s3_bucket_name = "${var.s3_logging_bucket_name}"
        s3_region = "${var.region}"
    }
}
