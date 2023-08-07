################################################################################
# source_bucket
################################################################################
resource "aws_s3_bucket" "source_bucket" {
  bucket = local.source_bucket_name
}

resource "aws_s3_bucket_versioning" "source_versioning" {
  bucket = aws_s3_bucket.source_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = local.source_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.job-submit.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".mov"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.job-submit.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".mp4"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

################################################################################
# destination_bucket
################################################################################
resource "aws_s3_bucket" "destination_bucket" {
  bucket = local.destination_bucket_name
}

resource "aws_s3_bucket_versioning" "destination_versioning" {
  bucket = aws_s3_bucket.destination_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "destination_bucket_cors" {
  bucket = aws_s3_bucket.destination_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

}