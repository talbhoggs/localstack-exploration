# Deployment Guide

## 📤 Overview

This guide covers the complete deployment process for the LocalStack serverless application.

## 🎯 Deployment Phases

1. **Prepare Environment** - Set up LocalStack and dependencies
2. **Package Lambda** - Bundle function code and dependencies
3. **Deploy Infrastructure** - Apply Terraform configuration
4. **Verify Deployment** - Test all components

## Phase 1: Prepare Environment

### Start LocalStack

```bash
# Start LocalStack container
docker-compose up -d

# Verify container is running
docker-compose ps

# Expected output:
# NAME                COMMAND             SERVICE       STATUS
# localstack-main     "docker-entrypoint…"   localstack    Up
```

### Check LocalStack Health

```bash
# Wait for LocalStack to be ready
curl http://localhost:4566/_localstack/health

# Wait until you see:
{
  "services": {
    "apigateway": "available",
    "iam": "available",
    "lambda": "available",
    "sqs": "available"
  }
}
```

**Tip**: This may take 30-60 seconds on first start.

## Phase 2: Package Lambda Function

### Understanding the Package

The Lambda function needs:
- **Source code**: `main.py`
- **Dependencies**: `boto3` and its dependencies
- **Format**: ZIP file

### Step-by-Step Packaging

#### 1. Create Package Directory

```bash
# Create fresh package directory
rm -rf package/
mkdir package
```

#### 2. Install Dependencies

```bash
# Install Python dependencies into package directory
pip install -r requirements.txt -t ./package

# Verify boto3 is installed
ls package/ | grep boto3
# Should show: boto3/ and botocore/
```

**What gets installed:**
- `boto3/` - AWS SDK for Python
- `botocore/` - Core functionality
- `dateutil/` - Date utilities
- `jmespath/` - JSON query language
- `s3transfer/` - S3 transfer utilities
- `six.py` - Python 2/3 compatibility
- `urllib3/` - HTTP library

#### 3. Copy Lambda Handler

```bash
# Copy main Lambda function
cp main.py ./package/

# Verify
ls package/main.py
```

#### 4. Create ZIP Archive

```bash
# Navigate to package directory
cd package

# Create ZIP file (includes all files in current directory)
zip -r my_lambda.zip .

# Verify ZIP contents
unzip -l my_lambda.zip | head -20

# Return to project root
cd ..
```

**Expected ZIP structure:**
```
my_lambda.zip
├── main.py
├── boto3/
├── botocore/
├── dateutil/
├── jmespath/
├── s3transfer/
├── six.py
└── urllib3/
```

### Alternative: One-Line Package Command

```bash
pip install -r requirements.txt -t ./package && \
cp main.py ./package/ && \
cd package && zip -r my_lambda.zip . && cd ..
```

## Phase 3: Deploy Infrastructure

### Initialize Terraform

```bash
# Initialize Terraform (first time only)
terraform init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# Terraform has been successfully initialized!
```

**What happens:**
- Downloads AWS provider plugin
- Creates `.terraform/` directory
- Creates `.terraform.lock.hcl` lock file

### Preview Changes

```bash
# See what will be created
terraform plan

# Review the output:
# Plan: 8 to add, 0 to change, 0 to destroy
```

**Resources to be created:**
1. `aws_iam_role.lambda_exec`
2. `aws_iam_role_policy.lambda_policy`
3. `aws_sqs_queue.my_queue`
4. `aws_lambda_function.my_lambda`
5. `aws_api_gateway_rest_api.rest_api`
6. `aws_api_gateway_resource.api`
7. `aws_api_gateway_resource.mylambda`
8. `aws_api_gateway_method.mylambda_post`
9. `aws_api_gateway_integration.mylambda_integration`
10. `aws_lambda_permission.apigw_lambda`
11. `aws_api_gateway_deployment.rest_deployment`

### Apply Configuration

```bash
# Deploy infrastructure
terraform apply

# Review plan and type 'yes' to confirm
# Or use auto-approve (use with caution)
terraform apply -auto-approve
```

**Expected output:**
```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

invoke_url_aws = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev/api/mylambda"
invoke_url_localstack = "http://localhost:4566/restapis/abc123xyz/dev/_user_request_/api/mylambda"
rest_api_id = "abc123xyz"
sqs_queue_url = "http://localhost:4566/000000000000/my-queue"
```

### Save Outputs

```bash
# Save API URL for testing
export API_URL=$(terraform output -raw invoke_url_localstack)
echo $API_URL

# Save queue URL
export QUEUE_URL=$(terraform output -raw sqs_queue_url)
echo $QUEUE_URL
```

## Phase 4: Verify Deployment

### 1. Verify IAM Role

```bash
aws --endpoint-url=http://localhost:4566 iam get-role \
  --role-name lambda_exec_role

# Should return role details
```

### 2. Verify SQS Queue

```bash
aws --endpoint-url=http://localhost:4566 sqs list-queues

# Expected output:
{
  "QueueUrls": [
    "http://localhost:4566/000000000000/my-queue"
  ]
}
```

### 3. Verify Lambda Function

```bash
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Should show my_lambda function
aws --endpoint-url=http://localhost:4566 lambda get-function \
  --function-name my_lambda
```

### 4. Verify API Gateway

```bash
aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis

# Should show MyRestApi
```

### 5. Test End-to-End

```bash
# Send test request
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"deployment","status":"success"}'

# Expected response:
{
  "message": "Payload sent to SQS successfully",
  "messageId": "..."
}
```

### 6. Verify Message in SQS

```bash
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url "$QUEUE_URL"

# Should show your test message
```

## 🔄 Redeployment

### Update Lambda Code Only

```bash
# 1. Modify main.py
vim main.py

# 2. Repackage
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..

# 3. Update Lambda (fast method)
aws --endpoint-url=http://localhost:4566 lambda update-function-code \
  --function-name my_lambda \
  --zip-file fileb://package/my_lambda.zip

# Or use Terraform (slower but safer)
terraform apply -auto-approve
```

### Update Infrastructure

```bash
# 1. Modify main.tf
vim main.tf

# 2. Preview changes
terraform plan

# 3. Apply changes
terraform apply
```

### Full Redeployment

```bash
# 1. Destroy existing resources
terraform destroy -auto-approve

# 2. Repackage Lambda
rm -rf package/
mkdir package
pip install -r requirements.txt -t ./package
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..

# 3. Redeploy
terraform apply -auto-approve
```

## 🎯 Deployment Checklist

- [ ] LocalStack container is running
- [ ] Health endpoint shows all services available
- [ ] Lambda package created successfully
- [ ] Terraform init completed
- [ ] Terraform plan shows expected resources
- [ ] Terraform apply completed without errors
- [ ] All outputs are displayed
- [ ] IAM role exists
- [ ] SQS queue exists
- [ ] Lambda function exists
- [ ] API Gateway exists
- [ ] End-to-end test passes
- [ ] Message appears in SQS

## 🚨 Common Deployment Issues

### Issue: Lambda Package Too Large

**Symptom**: Error about package size

**Solution**:
```bash
# Check package size
du -sh package/my_lambda.zip

# If too large, use Lambda layers or reduce dependencies
```

### Issue: Terraform State Lock

**Symptom**: "Error acquiring the state lock"

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### Issue: Resource Already Exists

**Symptom**: "Resource already exists"

**Solution**:
```bash
# Import existing resource
terraform import aws_lambda_function.my_lambda my_lambda

# Or destroy and recreate
terraform destroy -target=aws_lambda_function.my_lambda
terraform apply
```

### Issue: LocalStack Not Ready

**Symptom**: Connection refused errors

**Solution**:
```bash
# Wait for LocalStack to be ready
while ! curl -s http://localhost:4566/_localstack/health > /dev/null; do
  echo "Waiting for LocalStack..."
  sleep 2
done
echo "LocalStack is ready!"
```

## 📊 Deployment Metrics

### Typical Deployment Times

- **Lambda Packaging**: 30-60 seconds
- **Terraform Init**: 10-20 seconds (first time)
- **Terraform Apply**: 20-40 seconds
- **Total Deployment**: 1-2 minutes

### Resource Limits (LocalStack)

- **Lambda Package Size**: 50 MB (zipped)
- **Lambda Memory**: 128 MB - 3008 MB
- **Lambda Timeout**: 1 - 900 seconds
- **API Gateway Timeout**: 29 seconds

## 🔐 Production Deployment Differences

### LocalStack vs AWS

| Aspect | LocalStack | AWS Production |
|--------|-----------|----------------|
| **Endpoint** | localhost:4566 | AWS regional endpoints |
| **Credentials** | test/test | Real IAM credentials |
| **State Storage** | Local file | S3 backend recommended |
| **Deployment Time** | 1-2 minutes | 5-10 minutes |
| **Cost** | Free | Pay-per-use |

### Production Recommendations

1. **Use S3 Backend** for Terraform state
2. **Enable Versioning** for Lambda functions
3. **Use CI/CD Pipeline** for deployments
4. **Implement Blue/Green** deployment
5. **Add Monitoring** and alarms
6. **Enable Encryption** at rest and in transit

## 🔄 Rollback Strategy

### Quick Rollback

```bash
# Rollback to previous Lambda version
aws --endpoint-url=http://localhost:4566 lambda update-function-code \
  --function-name my_lambda \
  --zip-file fileb://backup/my_lambda.zip
```

### Full Rollback

```bash
# Restore previous Terraform state
cp terraform.tfstate.backup terraform.tfstate
terraform apply -auto-approve
```

---

**Next**: [Testing Guide →](04-TESTING.md)  
**Previous**: [← Architecture](02-ARCHITECTURE.md)