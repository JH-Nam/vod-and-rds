terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67"
    }
  }
}

provider "aws" {
  region = local.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = local.secondary_region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "primary" {}
data "aws_availability_zones" "secondary" {
  provider = aws.secondary
}
data "aws_partition" "current" {}

variable "email_address" {
    description = "put your email address"
    type = string
    default = "njh253087@gmail.com"
}

locals {
  name = "ex-${basename(path.cwd)}"

  source_bucket_name     = "${data.aws_caller_identity.current.account_id}-source-bucket"
  destination_bucket_name    = "${data.aws_caller_identity.current.account_id}-destination-bucket"
  s3_origin_id = "VodFoundationCloudFrontDistributionOrigin-test"

  primary_region   = "ap-northeast-2"
  primary_vpc_cidr = "10.0.0.0/16"
  primary_azs      = slice(data.aws_availability_zones.primary.names, 0, 3)

  secondary_region   = "us-east-1"
  secondary_vpc_cidr = "10.1.0.0/16"
  secondary_azs      = slice(data.aws_availability_zones.secondary.names, 0, 3)

  ingress_all = ["0.0.0.0/0"]

  master_username = "root"
  password = "qwer1234"

  publicly_accessible = true
  create_database_subnet_route_table = true
  create_database_internet_gateway_route = true

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-rds-aurora"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# cloudfront
################################################################################
resource "aws_cloudfront_origin_access_identity" "cloudfront_oai" {
  comment = "Identity for VodFoundationCloudFrontDistributionOrigin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.destination_bucket.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cloudfront_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Video on Demand Foundation"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress = true
    target_origin_id = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

}

################################################################################
# cloudwatch
################################################################################
resource "aws_cloudwatch_event_rule" "event_rule" {
  name        = "EventTriggerEventsRule"
  description = "catch media convert action"

  event_pattern = jsonencode({  
    "source": ["aws.mediaconvert"],
    "detail": {
      "userMetadata": {
        "StackName": ["StackName"]
      },
      "status": ["COMPLETE", "ERROR", "CANCELED", "INPUT_INFORMATION"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  arn       = aws_lambda_function.job-complete.arn
  rule      = aws_cloudwatch_event_rule.event_rule.name
  target_id = "job_complete_lambda"
  
}

################################################################################
# sns
################################################################################
resource "aws_sns_topic" "topic" {
  name = "mediaconvert_job_status"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "email"
  endpoint  = var.email_address
}