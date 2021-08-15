variable "name_prefix" {
  type        = string
  description = "Prefix that is used for the created resources. If specified, it will be '{name_prefix}-{name_suffix}'"
  default     = ""
}

variable "name_suffix" {
  type        = string
  description = "Suffix that is used for the created resources."
  default     = "move-cf-access-logs"
}

variable "s3_bucket_name" {
  type        = string
  description = "Bucket Name of access log files that are written by Amazon CloudFront"
}

variable "s3_bucket_new_key_prefix" {
  type        = string
  description = "Prefix of new access log files that are written by Amazon CloudFront. Including the trailing slash."
  default     = "raw/"
}

variable "create_s3_bucket_notification" {
  type        = bool
  description = "S3 Buckets only support a single notification configuration. ref.[aws_s3_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification)"
  default     = true
}

variable "s3_bucket_gz_key_prefix" {
  type        = string
  description = "Prefix of gzip'ed access log files that are moved to the Apache Hive like style. Including the trailing slash"
  default     = "partitioned-gz/"
}

variable "lambda_function_runtime" {
  type    = string
  default = "nodejs14.x"
}

variable "lambda_function_timeout" {
  type    = number
  default = 30
}

variable "lambda_function_publish" {
  type    = bool
  default = true
}

variable "lambda_function_log_retention_in_days" {
  type        = number
  description = "Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, and 0(never)"
  default     = 30
}
