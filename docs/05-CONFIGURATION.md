# Configuration Reference

## ⚙️ Overview

This guide covers all configuration options for the LocalStack serverless application.

## 📁 Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `docker-compose.yaml` | LocalStack container configuration | Root |
| `main.tf` | Infrastructure as Code | Root |
| `requirements.txt` | Python dependencies | Root |
| `.python-version` | Python version specification | Root |

## 🐳 LocalStack Configuration

### docker-compose.yaml

```yaml
services:
  localstack:
    container_name: "${LOCALSTACK_DOCKER_NAME:-localstack-main}"
    image: localstack/localstack
    ports:
      - "4566:4566"            # LocalStack Gateway
      - "4510-4559:4510-4559"  # External services port range
    environment:
      - DEBUG=1
      - DOCKER_HOST=unix:///var/run/docker.sock
      - LOCALSTACK_AUTH_TOKEN=ls-YOUR-TOKEN-HERE
    volumes:
      - "${LOCALSTACK_VOLUME_DIR:-./volume}:/var/lib/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
```

### Environment Variables

#### DEBUG
```yaml
- DEBUG=1  # Enable debug logging
- DEBUG=0  # Disable debug logging
```

**Purpose**: Controls logging verbosity  
**Default**: 0  
**Recommendation**: Enable (1) for development, disable (0) for production

#### LOCALSTACK_AUTH_TOKEN
```yaml
- LOCALSTACK_AUTH_TOKEN=ls-YOUR-TOKEN-HERE
```

**Purpose**: Authentication for LocalStack Pro features  
**Default**: None  
**Required**: No (for basic features)  
**Get Token**: https://app.localstack.cloud/

#### DOCKER_HOST
```yaml
- DOCKER_HOST=unix:///var/run/docker.sock
```

**Purpose**: Docker socket for Lambda execution  
**Default**: unix:///var/run/docker.sock  
**Required**: Yes (for Lambda functions)

#### SERVICES (Optional)
```yaml
- SERVICES=apigateway,lambda,sqs,iam
```

**Purpose**: Limit which AWS services to start  
**Default**: All services  
**Benefit**: Faster startup, lower memory usage

#### LAMBDA_EXECUTOR (Optional)
```yaml
- LAMBDA_EXECUTOR=docker        # Run in Docker containers (default)
- LAMBDA_EXECUTOR=local         # Run in local process
- LAMBDA_EXECUTOR=docker-reuse  # Reuse containers
```

**Purpose**: How Lambda functions are executed  
**Default**: docker  
**Recommendation**: docker for production-like behavior

#### Additional Options
```yaml
- LS_LOG=trace                  # Detailed logging
- EDGE_PORT=4566                # Change main port
- PERSISTENCE=1                 # Enable state persistence
- LAMBDA_REMOTE_DOCKER=0        # Disable remote Docker
```

### Port Configuration

```yaml
ports:
  - "4566:4566"            # Main LocalStack endpoint
  - "4510-4559:4510-4559"  # External services
```

**Change Main Port:**
```yaml
ports:
  - "8080:4566"  # Access via localhost:8080
environment:
  - EDGE_PORT=4566  # Keep internal port
```

### Volume Configuration

```yaml
volumes:
  - "${LOCALSTACK_VOLUME_DIR:-./volume}:/var/lib/localstack"
```

**Purpose**: Persist LocalStack data between restarts  
**Default**: ./volume  
**Change Location**:
```bash
export LOCALSTACK_VOLUME_DIR=/path/to/data
docker-compose up -d
```

## 🏗️ Terraform Configuration

### Provider Configuration

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    sqs        = "http://localhost:4566"
    iam        = "http://localhost:4566"
  }
}
```

### Customizable Variables

Create `variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "my_lambda"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 3
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "my-queue"
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "dev"
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}
```

### Use Variables in main.tf

```hcl
resource "aws_lambda_function" "my_lambda" {
  function_name = var.lambda_function_name
  runtime       = var.lambda_runtime
  handler       = "main.handler"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "package/my_lambda.zip"
  
  memory_size = var.lambda_memory
  timeout     = var.lambda_timeout
  
  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.my_queue.id
      LOG_LEVEL = "INFO"
    }
  }
}
```

### Override Variables

```bash
# Via command line
terraform apply -var="lambda_memory=256" -var="lambda_timeout=10"

# Via file
echo 'lambda_memory = 256' > terraform.tfvars
terraform apply
```

## 🐍 Lambda Configuration

### Environment Variables

Set in `main.tf`:

```hcl
environment {
  variables = {
    QUEUE_URL = aws_sqs_queue.my_queue.id
    LOG_LEVEL = "INFO"
    DEBUG     = "false"
    REGION    = "us-east-1"
  }
}
```

Access in `main.py`:

```python
import os

QUEUE_URL = os.environ["QUEUE_URL"]
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
DEBUG = os.environ.get("DEBUG", "false") == "true"
```

### Memory and Timeout

```hcl
resource "aws_lambda_function" "my_lambda" {
  memory_size = 256   # MB (128-10240)
  timeout     = 10    # seconds (1-900)
}
```

**Recommendations:**
- **Memory**: Start with 128 MB, increase if needed
- **Timeout**: 3-10 seconds for API Gateway integration

### Reserved Concurrent Executions

```hcl
resource "aws_lambda_function" "my_lambda" {
  reserved_concurrent_executions = 10
}
```

**Purpose**: Limit concurrent Lambda executions  
**Default**: Unreserved (unlimited)

## 📨 SQS Configuration

### Queue Settings

```hcl
resource "aws_sqs_queue" "my_queue" {
  name                       = "my-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600  # 4 days
  max_message_size          = 262144   # 256 KB
  delay_seconds             = 0
  receive_wait_time_seconds = 0
  
  # Dead Letter Queue (optional)
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}
```

### Dead Letter Queue

```hcl
resource "aws_sqs_queue" "dlq" {
  name = "my-queue-dlq"
}
```

## 🔐 IAM Configuration

### Lambda Execution Role

```hcl
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
```

### Custom Policies

```hcl
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["sqs:SendMessage", "sqs:GetQueueUrl"],
        Effect   = "Allow",
        Resource = aws_sqs_queue.my_queue.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:*:*:table/my-table"
      }
    ]
  })
}
```

## 🌐 API Gateway Configuration

### Stage Variables

```hcl
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.rest_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "dev"
  
  variables = {
    environment = "development"
    version     = "1.0"
  }
}
```

### Throttling

```hcl
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}
```

### CORS Configuration

```hcl
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.mylambda.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.mylambda.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.mylambda.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
```

## 🔧 AWS CLI Configuration

### Create Alias for LocalStack

```bash
# Add to ~/.bashrc or ~/.zshrc
alias awslocal="aws --endpoint-url=http://localhost:4566"

# Usage
awslocal s3 ls
awslocal sqs list-queues
```

### Configure AWS CLI Profile

```bash
# ~/.aws/config
[profile localstack]
region = us-east-1
output = json

# ~/.aws/credentials
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

**Usage:**
```bash
aws --profile localstack --endpoint-url=http://localhost:4566 sqs list-queues
```

## 📊 Configuration Best Practices

### Development
- ✅ Enable DEBUG logging
- ✅ Use default memory/timeout
- ✅ Disable authentication
- ✅ Use local volumes

### Production (AWS)
- ✅ Disable DEBUG logging
- ✅ Optimize memory/timeout
- ✅ Enable authentication
- ✅ Use S3 for Terraform state
- ✅ Enable encryption
- ✅ Set up monitoring

## 🔄 Configuration Management

### Environment-Specific Configs

```bash
# Development
terraform workspace new dev
terraform apply -var-file="dev.tfvars"

# Staging
terraform workspace new staging
terraform apply -var-file="staging.tfvars"

# Production
terraform workspace new prod
terraform apply -var-file="prod.tfvars"
```

### Secrets Management

**Never commit:**
- LocalStack auth tokens
- AWS credentials
- API keys

**Use:**
- Environment variables
- AWS Secrets Manager (production)
- HashiCorp Vault
- `.env` files (gitignored)

---

**Next**: [Troubleshooting →](06-TROUBLESHOOTING.md)  
**Previous**: [← Testing](04-TESTING.md)