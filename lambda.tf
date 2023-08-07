################################################################################
# job submit Lambda
################################################################################
resource "aws_lambda_function" "job-submit" {
  filename         = "./lambda_source/job-submit2.zip"
  function_name    = "job-submit"
  role             = aws_iam_role.job-submit-role.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("./lambda_source/job-submit2.zip")
  runtime          = "nodejs16.x"
  timeout          = 30

  description = "Submits an Encoding job to MediaConvert"

  environment {
    variables = {
      MEDIACONVERT_ROLE = aws_iam_role.mediaconvert-role.arn
      JOB_SETTINGS: "job-settings.json"
      DESTINATION_BUCKET: aws_s3_bucket.destination_bucket.id
      SOLUTION_ID: "SO0146"
      STACKNAME: "StackName"
      SOLUTION_IDENTIFIER: "AwsSolution/SO0146/v1.3.0"
      SNS_TOPIC_ARN: aws_sns_topic.topic.arn
      SNS_TOPIC_NAME: aws_sns_topic.topic.name
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "job-submit-eic" {
  function_name = aws_lambda_function.job-submit.function_name
  qualifier     = "$LATEST"
  maximum_retry_attempts = 0

}

resource "aws_lambda_permission" "allow_bucket" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job-submit.arn
  principal     = "s3.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id 
}

################################################################################
# job complete Lambda
################################################################################
resource "aws_lambda_function" "job-complete" {
  filename         = "./lambda_source/job-complete2.zip"
  function_name    = "job-complete"
  role             = aws_iam_role.job-complete-role.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("./lambda_source/job-complete2.zip")
  runtime          = "nodejs16.x"
  timeout          = 30

  description = "Triggered by Cloudwatch Events,processes completed MediaConvert jobs."

  environment {
    variables = {
      CLOUDFRONT_DOMAIN: aws_cloudfront_distribution.s3_distribution.domain_name
      SOURCE_BUCKET: aws_s3_bucket.source_bucket.id
      JOB_MANIFEST: "jobs-manifest.json"
      STACKNAME: "StackName"
      SOLUTION_ID: "SO0146"
      VERSION: "v1.3.0"
      SOLUTION_IDENTIFIER: "AwsSolution/SO0146/v1.3.0"
      SNS_TOPIC_ARN: aws_sns_topic.topic.arn
      SNS_TOPIC_NAME: aws_sns_topic.topic.name
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "job-complete-eic" {
  function_name = aws_lambda_function.job-complete.function_name
  qualifier     = "$LATEST"
  maximum_retry_attempts = 0

}

resource "aws_lambda_permission" "allow_bucket2" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job-complete.arn
  principal     = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.event_rule.arn
}