/**
 * # terraform-aws-cloudfront-access-logs-to-hive-format
 *
 * A Terraform template that move CloudFront Access Logs to Hive format for Athena.
 * 
 * ## Reference
 *
 * - [aws-samples/amazon-cloudfront-access-logs-queries](https://github.com/aws-samples/amazon-cloudfront-access-logs-queries)
 *     - "This moves the file to an Apache Hive style prefix." part
 *
 * ### Changes
 *
 * - CloudFormation stack to TerraForm
 * - Use only moveAccessLogs
 * - Keep the prefix and put it in front of the datetime
 *
 * ## Overview
 *
 * ![overview](images/terraform-aws-cloudfront-access-logs-to-hive-format.png)
 *
 * - e.g.
 *     - CloudFront logging setting:
 *         - S3 bucket: example-bucket
 *         - Log prefix: raw/example.com
 *     - Inputs:
 *         - new_key_prefix: raw/
 *         - gz_key_prefix: partitioned-gz/
 *     - Result:
 *         - source:
 *             - s3://example-bucket/raw/example.com/XXXXXXXXXXXXX.1990-01-01-00.XXXXXXXX.gz
 *         - destination:
 *             - S3: s3://example-bucket/partitioned-gz/example.com/year=1990/month=01/day=01/hour=00/XXXXXXXXXXXXX.1990-01-01-00.XXXXXXXX.gz
 */

terraform {
  required_version = ">= 1.0.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.52"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2"
    }
  }
}

locals {
  name = length(var.name_prefix) > 0 ? "${var.name_prefix}-${var.name_suffix}" : var.name_suffix
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "this_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      identifiers = [
        "lambda.amazonaws.com",
      ]
      type = "Service"
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}/${var.s3_bucket_new_key_prefix}*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}/${var.s3_bucket_gz_key_prefix}*"
    ]
  }
}

resource "aws_iam_role" "this" {
  name               = local.name
  assume_role_policy = data.aws_iam_policy_document.this_assume_role_policy.json

  tags = {
    Name = local.name
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "moveAccessLogs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = "${path.module}/functions/moveAccessLogs"
  output_path = "${path.module}/functions/uploads/${local.name}.zip"
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.this.output_path
  function_name    = local.name
  role             = aws_iam_role.this.arn
  handler          = "moveAccessLogs.handler"
  source_code_hash = data.archive_file.this.output_base64sha256

  runtime = var.lambda_function_runtime
  timeout = var.lambda_function_timeout
  publish = false

  environment {
    variables = {
      SOURCE_KEY_PREFIX = var.s3_bucket_new_key_prefix
      TARGET_KEY_PREFIX = var.s3_bucket_gz_key_prefix
    }
  }

  tags = {
    Name = local.name
  }
}

resource "aws_lambda_permission" "this" {
  statement_id_prefix = aws_lambda_function.this.function_name
  action              = "lambda:InvokeFunction"
  function_name       = aws_lambda_function.this.arn
  principal           = "s3.amazonaws.com"
  source_arn          = "arn:aws:s3:::${var.s3_bucket_name}"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = var.lambda_function_log_retention_in_days
  kms_key_id        = aws_kms_key.this.arn

  tags = {
    Name = aws_lambda_function.this.function_name
  }
}

resource "aws_s3_bucket_notification" "this" {
  count      = var.create_s3_bucket_notification ? 1 : 0
  depends_on = [aws_lambda_permission.this]

  bucket = var.s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_bucket_new_key_prefix
    filter_suffix       = ""
  }
}
