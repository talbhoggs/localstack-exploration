provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  
  endpoints {
    apigateway = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    sqs        = "http://localhost:4566"
    iam        = "http://localhost:4566"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach basic execution policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["sqs:SendMessage"],
        Effect   = "Allow",
        Resource = aws_sqs_queue.my_queue.arn
      },
      {
        Action   = ["logs:*"],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# SQS queue
resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
}

# Lambda function
resource "aws_lambda_function" "my_lambda" {
  function_name = "my_lambda"
  runtime       = "python3.12"
  handler       = "main.handler"
  role          = aws_iam_role.lambda_exec.arn

  filename      = "package/my_lambda.zip"
  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.my_queue.id
    }
  }
}

# API Gateway v1 (REST API)
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "MyRestApi"
  description = "REST API for Lambda → SQS"
}

# Resource path /api
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "api"
}

# Resource path /api/mylambda
resource "aws_api_gateway_resource" "mylambda" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "mylambda"
}

# Method
resource "aws_api_gateway_method" "mylambda_post" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.mylambda.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration with Lambda
resource "aws_api_gateway_integration" "mylambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.mylambda.id
  http_method             = aws_api_gateway_method.mylambda_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda.invoke_arn
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "rest_deployment" {
  depends_on  = [aws_api_gateway_integration.mylambda_integration]
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
}

# Stage resource (this is where stage_name belongs)
resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  deployment_id = aws_api_gateway_deployment.rest_deployment.id
  stage_name    = "dev"
}

# Outputs
output "rest_api_id" {
  value = aws_api_gateway_rest_api.rest_api.id
}

# LocalStack invoke URL (requires _user_request_)
output "invoke_url_localstack" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.rest_api.id}/dev/_user_request_/api/mylambda"
}

# AWS invoke URL (clean format)
output "invoke_url_aws" {
  value = "https://${aws_api_gateway_rest_api.rest_api.id}.execute-api.us-east-1.amazonaws.com/dev/api/mylambda"
}

output "sqs_queue_url" {
  value = aws_sqs_queue.my_queue.id
}
