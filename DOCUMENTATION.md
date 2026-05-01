# LocalStack AWS Serverless Development Environment

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Detailed Setup](#detailed-setup)
6. [Deployment Guide](#deployment-guide)
7. [Testing & Usage](#testing--usage)
8. [Configuration Reference](#configuration-reference)
9. [Development Workflow](#development-workflow)
10. [Troubleshooting](#troubleshooting)
11. [Additional Resources](#additional-resources)

---

## 🎯 Project Overview

This project demonstrates a **serverless event-driven architecture** using AWS services, running entirely on **LocalStack** for local development and testing. It eliminates the need for an AWS account during development while maintaining production-like behavior.

### Purpose

- **Local AWS Development**: Test AWS services without cloud costs
- **Infrastructure as Code**: Reproducible deployments using Terraform
- **Serverless Pattern**: API Gateway → Lambda → SQS message queue
- **Event-Driven Architecture**: Decoupled, scalable message processing

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Cloud Emulation | LocalStack | Latest |
| Infrastructure | Terraform | >= 1.0 |
| Runtime | Python | 3.12 |
| AWS SDK | Boto3 | Latest |
| Container | Docker | >= 20.10 |
| CLI | AWS CLI | >= 2.0 |

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐      ┌─────────────┐
│   Client    │─────▶│ API Gateway  │─────▶│   Lambda    │─────▶│  SQS Queue  │
│  (HTTP POST)│      │  (REST API)  │      │  Function   │      │  (my-queue) │
└─────────────┘      └──────────────┘      └─────────────┘      └─────────────┘
                            │
                            │
                            ▼
                     ┌──────────────┐
                     │     IAM      │
                     │  Permissions │
                     └──────────────┘
```

### Request Flow

1. **Client** sends HTTP POST request with JSON payload to API Gateway endpoint
2. **API Gateway** validates request and triggers Lambda function
3. **Lambda Function** processes the request:
   - Parses JSON body
   - Sends message to SQS queue
   - Returns success/error response
4. **SQS Queue** stores message for downstream processing
5. **Response** returns to client with message ID

### AWS Services Used

#### 1. **API Gateway (REST API)**
- **Endpoint**: `/api/mylambda`
- **Method**: POST
- **Integration**: AWS_PROXY with Lambda
- **Stage**: dev

#### 2. **Lambda Function**
- **Name**: my_lambda
- **Runtime**: Python 3.12
- **Handler**: main.handler
- **Memory**: Default (128 MB)
- **Timeout**: Default (3 seconds)

#### 3. **SQS Queue**
- **Name**: my-queue
- **Type**: Standard Queue
- **Purpose**: Message storage and decoupling

#### 4. **IAM Role & Policy**
- **Role**: lambda_exec_role
- **Permissions**:
  - SQS: SendMessage
  - CloudWatch Logs: Full access (permission granted but not explicitly configured)

---

## 📦 Prerequisites

### Required Software

1. **Docker Desktop**
   ```bash
   # Verify installation
   docker --version
   # Should be >= 20.10
   ```

2. **Terraform**
   ```bash
   # Install via Homebrew (macOS)
   brew install terraform
   
   # Verify installation
   terraform --version
   # Should be >= 1.0
   ```

3. **AWS CLI**
   ```bash
   # Install via Homebrew (macOS)
   brew install awscli
   
   # Verify installation
   aws --version
   # Should be >= 2.0
   ```

4. **Python**
   ```bash
   # Verify installation
   python3 --version
   # Should be >= 3.8
   ```

5. **pip (Python Package Manager)**
   ```bash
   # Verify installation
   pip3 --version
   ```

### LocalStack Account (Optional but Recommended)

1. Sign up at [LocalStack](https://app.localstack.cloud/)
2. Get your authentication token
3. Update `docker-compose.yaml` with your token

---

## 🚀 Quick Start

Get up and running in 5 minutes:

```bash
# 1. Start LocalStack
docker-compose up -d

# 2. Wait for LocalStack to be ready (check logs)
docker-compose logs -f

# 3. Package Lambda function
pip install -r requirements.txt -t ./package
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..

# 4. Initialize and deploy infrastructure
terraform init
terraform apply -auto-approve

# 5. Get API endpoint
terraform output invoke_url_localstack

# 6. Test the API
curl -X POST "$(terraform output -raw invoke_url_localstack)" \
  -H "Content-Type: application/json" \
  -d '{"hello":"world","message":"test"}'

# 7. Verify message in SQS
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/my-queue
```

---

## 🔧 Detailed Setup

### Step 1: Clone and Navigate

```bash
cd /path/to/localstack
```

### Step 2: Configure LocalStack

Edit `docker-compose.yaml` if needed:

```yaml
environment:
  - DEBUG=1  # Enable debug logging
  - LOCALSTACK_AUTH_TOKEN=your-token-here  # Optional
```

### Step 3: Start LocalStack Container

```bash
# Start in detached mode
docker-compose up -d

# Check container status
docker-compose ps

# View logs
docker-compose logs -f localstack
```

**Wait for this message**: `Ready.` in the logs

### Step 4: Verify LocalStack Services

```bash
# Check health endpoint
curl http://localhost:4566/_localstack/health

# Expected output shows available services
{
  "services": {
    "apigateway": "available",
    "lambda": "available",
    "sqs": "available",
    ...
  }
}
```

---

## 📤 Deployment Guide

### Phase 1: Package Lambda Function

The Lambda function needs its dependencies packaged together:

```bash
# Create package directory (if not exists)
mkdir -p package

# Install dependencies into package directory
pip install -r requirements.txt -t ./package

# Copy Lambda handler
cp main.py ./package/

# Create deployment package
cd package
zip -r my_lambda.zip .
cd ..
```

**What's included in the package:**
- `main.py` - Lambda handler function
- `boto3/` - AWS SDK for Python
- `botocore/` - Core functionality for boto3
- Other dependencies

### Phase 2: Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

### Phase 3: Deploy Infrastructure

```bash
# Apply configuration
terraform apply

# Review the plan and type 'yes' to confirm

# Or auto-approve (use with caution)
terraform apply -auto-approve
```

**Resources Created:**
- IAM Role: `lambda_exec_role`
- IAM Policy: `lambda_policy`
- SQS Queue: `my-queue`
- Lambda Function: `my_lambda`
- API Gateway: `MyRestApi`
- API Gateway Deployment: `dev` stage

### Phase 4: Verify Deployment

```bash
# Get outputs
terraform output

# Expected outputs:
# rest_api_id = "abc123xyz"
# invoke_url_localstack = "http://localhost:4566/restapis/abc123xyz/dev/_user_request_/api/mylambda"
# invoke_url_aws = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev/api/mylambda"
# sqs_queue_url = "http://localhost:4566/000000000000/my-queue"
```

---

## 🧪 Testing & Usage

### Test 1: Basic API Request

```bash
# Get the API endpoint
API_URL=$(terraform output -raw invoke_url_localstack)

# Send test request
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"hello":"world"}'

# Expected response:
{
  "message": "Payload sent to SQS successfully",
  "messageId": "12345678-1234-1234-1234-123456789012"
}
```

### Test 2: Complex Payload

```bash
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "action": "purchase",
    "items": [
      {"id": "item1", "quantity": 2},
      {"id": "item2", "quantity": 1}
    ],
    "timestamp": "2026-05-01T09:00:00Z"
  }'
```

### Test 3: Verify SQS Messages

```bash
# Receive message from queue
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/my-queue \
  --max-number-of-messages 10

# Expected output shows messages with Body containing your JSON payload
```

### Test 4: Check Lambda Logs (LocalStack Auto-Generated)

**Note**: CloudWatch Logs are not explicitly configured in the Terraform code, but LocalStack automatically creates log groups for Lambda functions.

```bash
# List log groups (LocalStack may auto-create these)
aws --endpoint-url=http://localhost:4566 logs describe-log-groups

# Get log streams for Lambda (if available)
aws --endpoint-url=http://localhost:4566 logs describe-log-streams \
  --log-group-name /aws/lambda/my_lambda

# Read logs (if available)
aws --endpoint-url=http://localhost:4566 logs tail \
  /aws/lambda/my_lambda --follow
```

### Test 5: Error Handling

```bash
# Send invalid JSON
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d 'invalid json'

# Expected response:
{
  "error": "Expecting value: line 1 column 1 (char 0)"
}
```

### Using Python Script for Testing

Create `test_api.py`:

```python
import requests
import json

API_URL = "http://localhost:4566/restapis/YOUR_API_ID/dev/_user_request_/api/mylambda"

def test_api():
    payload = {
        "test": "data",
        "timestamp": "2026-05-01T09:00:00Z"
    }
    
    response = requests.post(
        API_URL,
        json=payload,
        headers={"Content-Type": "application/json"}
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    test_api()
```

Run it:
```bash
python test_api.py
```

---

## ⚙️ Configuration Reference

### Terraform Variables

Currently, the configuration uses hardcoded values. To make it more flexible, you can add variables:

**Create `variables.tf`:**

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
```

### Environment Variables

#### Lambda Function Environment Variables

Set in `main.tf`:

```hcl
environment {
  variables = {
    QUEUE_URL = aws_sqs_queue.my_queue.id
    LOG_LEVEL = "INFO"  # Add custom variables
  }
}
```

#### LocalStack Environment Variables

Set in `docker-compose.yaml`:

```yaml
environment:
  - DEBUG=1                    # Enable debug logging
  - DOCKER_HOST=unix:///var/run/docker.sock
  - LOCALSTACK_AUTH_TOKEN=...  # Your auth token
  - SERVICES=apigateway,lambda,sqs,iam  # Limit services
  - LAMBDA_EXECUTOR=docker     # Lambda execution mode
```

### AWS CLI Configuration

For LocalStack, always use `--endpoint-url`:

```bash
# Create alias for convenience
alias awslocal="aws --endpoint-url=http://localhost:4566"

# Now use it
awslocal s3 ls
awslocal sqs list-queues
```

---

## 🔄 Development Workflow

### Making Changes to Lambda Function

1. **Edit the Lambda code**:
   ```bash
   vim main.py
   ```

2. **Repackage**:
   ```bash
   cp main.py ./package/
   cd package && zip -r my_lambda.zip . && cd ..
   ```

3. **Update Lambda**:
   ```bash
   # Option 1: Via Terraform
   terraform apply -auto-approve
   
   # Option 2: Via AWS CLI (faster for code-only changes)
   aws --endpoint-url=http://localhost:4566 lambda update-function-code \
     --function-name my_lambda \
     --zip-file fileb://package/my_lambda.zip
   ```

4. **Test changes**:
   ```bash
   curl -X POST "$API_URL" -H "Content-Type: application/json" -d '{"test":"data"}'
   ```

### Adding New Dependencies

1. **Update `requirements.txt`**:
   ```bash
   echo "requests" >> requirements.txt
   ```

2. **Reinstall dependencies**:
   ```bash
   pip install -r requirements.txt -t ./package
   ```

3. **Repackage and deploy**:
   ```bash
   cd package && zip -r my_lambda.zip . && cd ..
   terraform apply -auto-approve
   ```

### Modifying Infrastructure

1. **Edit `main.tf`**:
   ```bash
   vim main.tf
   ```

2. **Plan changes**:
   ```bash
   terraform plan
   ```

3. **Apply changes**:
   ```bash
   terraform apply
   ```

### Destroying Resources

```bash
# Destroy all resources
terraform destroy

# Or destroy specific resource
terraform destroy -target=aws_lambda_function.my_lambda
```

### Resetting LocalStack

```bash
# Stop and remove container
docker-compose down

# Remove persistent data
rm -rf volume/

# Start fresh
docker-compose up -d
```

---

## 🔍 Troubleshooting

### Issue 1: LocalStack Not Starting

**Symptoms:**
- Container exits immediately
- Port 4566 not accessible

**Solutions:**

```bash
# Check Docker is running
docker ps

# Check logs
docker-compose logs localstack

# Verify port is not in use
lsof -i :4566

# Restart with fresh state
docker-compose down -v
docker-compose up -d
```

### Issue 2: Lambda Function Not Found

**Symptoms:**
- Error: "Function not found"
- 404 when invoking

**Solutions:**

```bash
# List Lambda functions
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Check Terraform state
terraform state list

# Redeploy
terraform apply -replace=aws_lambda_function.my_lambda
```

### Issue 3: API Gateway 403 Forbidden

**Symptoms:**
- 403 error when calling API
- "Missing Authentication Token"

**Solutions:**

```bash
# Verify API Gateway exists
aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis

# Check the correct URL format for LocalStack
# Must include: /restapis/{api-id}/{stage}/_user_request_/{path}

# Get correct URL from Terraform
terraform output invoke_url_localstack
```

### Issue 4: SQS Messages Not Appearing

**Symptoms:**
- Lambda succeeds but no messages in queue
- Empty receive-message response

**Solutions:**

```bash
# Verify queue exists
aws --endpoint-url=http://localhost:4566 sqs list-queues

# Check Lambda has correct QUEUE_URL
aws --endpoint-url=http://localhost:4566 lambda get-function-configuration \
  --function-name my_lambda

# Check Lambda logs for errors
aws --endpoint-url=http://localhost:4566 logs tail /aws/lambda/my_lambda

# Test sending directly to SQS
aws --endpoint-url=http://localhost:4566 sqs send-message \
  --queue-url http://localhost:4566/000000000000/my-queue \
  --message-body "test"
```

### Issue 5: Terraform State Issues

**Symptoms:**
- "Resource already exists"
- State drift errors

**Solutions:**

```bash
# Import existing resource
terraform import aws_lambda_function.my_lambda my_lambda

# Refresh state
terraform refresh

# Nuclear option: reset state
rm terraform.tfstate*
terraform init
terraform apply
```

### Issue 6: Python Dependencies Missing

**Symptoms:**
- "No module named 'boto3'"
- Import errors in Lambda

**Solutions:**

```bash
# Verify package contents
unzip -l package/my_lambda.zip | grep boto3

# Reinstall dependencies
rm -rf package/
mkdir package
pip install -r requirements.txt -t ./package
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..

# Redeploy
terraform apply -auto-approve
```

### Issue 7: LocalStack Auth Token Issues

**Symptoms:**
- "Invalid auth token"
- Limited functionality

**Solutions:**

1. Get valid token from [LocalStack Dashboard](https://app.localstack.cloud/)
2. Update `docker-compose.yaml`
3. Restart container:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Debug Mode

Enable verbose logging:

```bash
# In docker-compose.yaml
environment:
  - DEBUG=1
  - LS_LOG=trace

# Restart
docker-compose restart

# Follow logs
docker-compose logs -f
```

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Connection refused` | LocalStack not running | `docker-compose up -d` |
| `Invalid JSON` | Malformed request body | Validate JSON syntax |
| `AccessDenied` | IAM permissions issue | Check Lambda role policy |
| `ResourceNotFoundException` | Resource doesn't exist | Verify with `terraform state list` |
| `ValidationException` | Invalid parameter | Check AWS CLI command syntax |

---

## 📚 Additional Resources

### Official Documentation

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [AWS API Gateway](https://docs.aws.amazon.com/apigateway/)
- [AWS SQS](https://docs.aws.amazon.com/sqs/)

### Tutorials & Guides

- [Original Tutorial Video](https://www.youtube.com/watch?v=XPFl28a0mrQ&t=23s)
- [GitHub Repository](https://github.com/marcogreiveldinger/videos/tree/main/localstack)
- [LocalStack Getting Started](https://docs.localstack.cloud/getting-started/)
- [Terraform LocalStack Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/custom-service-endpoints#localstack)

### Tools & Extensions

- **LocalStack Desktop**: GUI for managing LocalStack
- **awslocal**: Wrapper for AWS CLI with LocalStack endpoints
- **Terraform LocalStack Provider**: Alternative to AWS provider
- **VS Code Extensions**:
  - Terraform
  - AWS Toolkit
  - Python

### Community

- [LocalStack Slack](https://localstack.cloud/slack)
- [LocalStack Discuss](https://discuss.localstack.cloud/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/localstack)

### Best Practices

1. **Version Control**: Always commit `terraform.tfstate` to `.gitignore`
2. **Environment Variables**: Use `.env` files for sensitive data
3. **Testing**: Write integration tests for Lambda functions
4. **CI/CD**: Integrate LocalStack in CI pipelines
5. **Monitoring**: Use CloudWatch Logs for debugging
6. **Security**: Never commit auth tokens or credentials

### Next Steps

- **Add More Services**: S3, DynamoDB, SNS
- **Implement CI/CD**: GitHub Actions with LocalStack
- **Add Tests**: Unit and integration tests
- **Monitoring**: Set up CloudWatch dashboards
- **Documentation**: API documentation with OpenAPI/Swagger
- **Security**: Implement API authentication

---

## 📝 Project Structure Reference

```
localstack/
├── main.tf                      # Terraform infrastructure definition
├── main.py                      # Lambda function source code
├── docker-compose.yaml          # LocalStack container configuration
├── requirements.txt             # Python dependencies
├── README.md                    # Quick reference (original)
├── DOCUMENTATION.md             # This comprehensive guide
│
├── package/                     # Lambda deployment package
│   ├── main.py                 # Lambda handler (copy)
│   ├── my_lambda.zip           # Zipped deployment package
│   ├── boto3/                  # AWS SDK
│   ├── botocore/               # Core AWS functionality
│   └── [other dependencies]
│
├── volume/                      # LocalStack persistent data
│   ├── cache/                  # Service cache
│   └── [runtime data]
│
├── .terraform/                  # Terraform plugins and modules
├── terraform.tfstate            # Terraform state (DO NOT COMMIT)
├── terraform.tfstate.backup     # State backup
└── .python-version              # Python version specification
```

---

## 🎓 Learning Path

### Beginner
1. ✅ Understand the architecture
2. ✅ Deploy the basic setup
3. ✅ Test API endpoints
4. ✅ View SQS messages

### Intermediate
1. Modify Lambda function logic
2. Add error handling
3. Implement logging
4. Add new API endpoints

### Advanced
1. Add more AWS services (S3, DynamoDB)
2. Implement authentication
3. Set up CI/CD pipeline
4. Performance optimization
5. Production deployment strategy

---

## 📄 License

This project is for educational purposes. Refer to individual component licenses:
- LocalStack: [License](https://github.com/localstack/localstack/blob/master/LICENSE.txt)
- Terraform: [MPL 2.0](https://github.com/hashicorp/terraform/blob/main/LICENSE)
- AWS SDK: [Apache 2.0](https://github.com/boto/boto3/blob/develop/LICENSE)

---

## 🤝 Contributing

To extend this project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with LocalStack
5. Submit a pull request

---

**Last Updated**: 2026-05-01  
**Version**: 1.0.0  
**Maintained By**: Development Team

For questions or issues, please refer to the [Troubleshooting](#troubleshooting) section or consult the [Additional Resources](#additional-resources).