resource "aws_iam_role" "job-submit-role" {
  name               = "job-submit-role"
  assume_role_policy = data.aws_iam_policy_document.job-submit-role_trust.json
}

resource "aws_iam_role_policy" "job-submit-policy" {
    name = "job-submit-policy"
    role = aws_iam_role.job-submit-role.id

    policy = data.aws_iam_policy_document.job-submit-role_policy.json
}

resource "aws_iam_role" "job-complete-role" {
  name               = "job-complete-role"
  assume_role_policy = data.aws_iam_policy_document.job-complete-role_trust.json
}

resource "aws_iam_role_policy" "job-complete-policy" {
    name = "job-complete-policy"
    role = aws_iam_role.job-complete-role.id

    policy = data.aws_iam_policy_document.job-complete-role_policy.json
}

resource "aws_iam_role" "mediaconvert-role" {
    name = "mediaconvert-role"
    assume_role_policy = data.aws_iam_policy_document.mediaconvert-role_trust.json
}

resource "aws_iam_role_policy" "mediaconvert-policy" {
    name = "mediaconvert-policy"
    role = aws_iam_role.mediaconvert-role.id

    policy = data.aws_iam_policy_document.mediaconvert-role_policy.json
}

resource "aws_s3_bucket_policy" "source-bucket-policy" {
  bucket = aws_s3_bucket.source_bucket.id
  policy = data.aws_iam_policy_document.source-bucket-policy.json
}

resource "aws_s3_bucket_policy" "destination-bucket-policy" {
  bucket = aws_s3_bucket.destination_bucket.id
  policy = data.aws_iam_policy_document.destination-bucket-policy.json
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.topic.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

/////////////////////// data ///////////////////////////////////
data "aws_iam_policy_document" "job-submit-role_trust" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
    }
}

data "aws_iam_policy_document" "job-complete-role_trust" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
    }
}

data "aws_iam_policy_document" "mediaconvert-role_trust" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
        type        = "Service"
        identifiers = ["mediaconvert.amazonaws.com"]
        }
    }
}

data "aws_iam_policy_document" "job-submit-role_policy" {
    statement {
        effect = "Allow"
        actions = [
            "iam:PassRole"
        ]
        resources = ["${aws_iam_role.mediaconvert-role.arn}"]
    }

    statement {
        effect = "Allow"
        actions = [
            "mediaconvert:CreateJob"
        ]
        resources = [
            "arn:${data.aws_partition.current.partition}:mediaconvert:${local.primary_region}:${data.aws_caller_identity.current.account_id}:*"
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "s3:GetObject"
        ]
        resources = [
            aws_s3_bucket.source_bucket.arn,
            "${aws_s3_bucket.source_bucket.arn}/*"
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "sns:Publish"
        ]
        resources = [
            aws_sns_topic.topic.arn
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "mediaconvert:DescribeEndpoints"
        ]
        resources = [
            "arn:aws:mediaconvert:${local.primary_region}:${data.aws_caller_identity.current.account_id}:*"
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        resources = [
            "*"
        ]
    }

}

data "aws_iam_policy_document" "job-complete-role_policy" {
    statement {
        effect = "Allow"
        actions = [
            "mediaconvert:GetJob"
        ]
        resources = [
            "arn:${data.aws_partition.current.partition}:mediaconvert:${local.primary_region}:${data.aws_caller_identity.current.account_id}:*"
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "s3:GetObject",
            "s3:PutObject"
        ]
        resources = [
            "${aws_s3_bucket.source_bucket.arn}/*"
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "sns:Publish"
        ]
        resources = [
            aws_sns_topic.topic.arn
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "mediaconvert:DescribeEndpoints"
        ]
        resources = [
            "arn:aws:mediaconvert:${local.primary_region}:${data.aws_caller_identity.current.account_id}:*"
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        resources = [
            "*"
        ]
    }

}

data "aws_iam_policy_document" "mediaconvert-role_policy" {
    statement {
        effect = "Allow"
        actions = [
            "s3:GetObject",
            "s3:PutObject"
        ]
        resources = [
            "${aws_s3_bucket.source_bucket.arn}/*",
            "${aws_s3_bucket.destination_bucket.arn}/*"
        ]
    }

    statement {
      effect = "Allow"
      actions = [
        "execute-api:Invoke"
      ]
      resources = [
        "arn:${data.aws_partition.current.partition}:execute-api:${local.primary_region}:${data.aws_caller_identity.current.account_id}:*"
      ]
      
    }

}

data "aws_iam_policy_document" "source-bucket-policy" {
  statement {
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.source_bucket.arn,
      "${aws_s3_bucket.source_bucket.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "destination-bucket-policy" {
  statement {
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.destination_bucket.arn,
      "${aws_s3_bucket.destination_bucket.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    principals {
      type        = "CanonicalUser"
      identifiers = ["${aws_cloudfront_origin_access_identity.cloudfront_oai.s3_canonical_user_id}"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.destination_bucket.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    resources = [
      aws_sns_topic.topic.arn
    ]

    sid = "TopicOwnerOnlyAccess"
  }

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.topic.arn
    ]

    sid = "HttpsOnly"
  }
}