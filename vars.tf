variable "region" {
    type = "string"
    default = "us-east-2"
}

variable "profile" {
    type = "string"
}

variable "ec2_key_pair_name" {
    type = "string"
}

variable "s3_logging_bucket_name" {
    type = "string"
}
