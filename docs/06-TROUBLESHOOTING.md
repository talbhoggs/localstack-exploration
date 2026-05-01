# Troubleshooting Guide

## 🔍 Overview

This guide covers common issues and their solutions when working with LocalStack.

## 🚨 Quick Diagnostics

### Health Check Script

```bash
#!/bin/bash
echo "=== LocalStack Diagnostics ==="

echo "1. Docker Status:"
docker ps | grep localstack

echo -e "\n2. LocalStack Health:"
curl -s http://localhost:4566/_localstack/health | jq .

echo -e "\n3. Terraform State:"
terraform state list

echo -e "\n4. Lambda Functions:"
aws --endpoint-url=http://localhost:4566 lambda list-functions | jq .

echo -e "\n5. SQS Queues:"
aws --endpoint-url=http://localhost:4566 sqs list-queues | jq .

echo -e "\n6. API Gateways:"
aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis | jq .
```

## 🐳 LocalStack Issues

### Issue 1: LocalStack Won't Start

**Symptoms:**
- Container exits immediately
- `docker-compose up` fails
- Port 4566 not accessible

**Diagnosis:**
```bash
# Check Docker is running
docker ps

# Check container logs
docker-compose logs localstack

# Check port availability
lsof -i :4566
```

**Solutions:**

**Solution A: Port Already in Use**
```bash
# Find process using port 4566
lsof -i :4566

# Kill the process
kill -9 <PID>

# Or change port in docker-compose.yaml
ports:
  - "8080:4566"
```

**Solution B: Docker Not Running**
```bash
# Start Docker Desktop
open -a Docker

# Wait for Docker to start
docker ps
```

**Solution C: Insufficient Resources**
```bash
# Increase Docker resources in Docker Desktop
# Settings → Resources → Memory: 4GB+
```

**Solution D: Clean Start**
```bash
# Remove everything and start fresh
docker-compose down -v
rm -rf volume/
docker-compose up -d
```

### Issue 2: LocalStack Services Not Available

**Symptoms:**
- Health check shows services as "unavailable"
- API calls fail with connection errors

**Diagnosis:**
```bash
# Check health endpoint
curl http://localhost:4566/_localstack/health

# Check logs for errors
docker-compose logs -f localstack
```

**Solutions:**

**Solution A: Wait for Initialization**
```bash
# LocalStack needs time to start (30-60 seconds)
while ! curl -s http://localhost:4566/_localstack/health > /dev/null; do
  echo "Waiting for LocalStack..."
  sleep 2
done
echo "LocalStack is ready!"
```

**Solution B: Restart Container**
```bash
docker-compose restart localstack
```

**Solution C: Check Auth Token**
```yaml
# In docker-compose.yaml
environment:
  - LOCALSTACK_AUTH_TOKEN=ls-YOUR-VALID-TOKEN
```

### Issue 3: LocalStack Crashes or Freezes

**Symptoms:**
- Container stops unexpectedly
- No response from endpoints
- High CPU/memory usage

**Diagnosis:**
```bash
# Check container status
docker stats localstack-main

# Check logs for errors
docker-compose logs --tail=100 localstack
```

**Solutions:**

**Solution A: Increase Resources**
```bash
# Docker Desktop → Settings → Resources
# Memory: 4GB minimum, 8GB recommended
# CPUs: 2 minimum, 4 recommended
```

**Solution B: Limit Services**
```yaml
# In docker-compose.yaml
environment:
  - SERVICES=apigateway,lambda,sqs,iam
```

**Solution C: Clean Restart**
```bash
docker-compose down
rm -rf volume/
docker-compose up -d
```

## 🏗️ Terraform Issues

### Issue 4: Terraform Init Fails

**Symptoms:**
- "Failed to install provider"
- "Error installing provider"

**Diagnosis:**
```bash
# Check Terraform version
terraform version

# Check internet connection
ping registry.terraform.io
```

**Solutions:**

**Solution A: Clear Cache**
```bash
rm -rf .terraform/
rm .terraform.lock.hcl
terraform init
```

**Solution B: Update Terraform**
```bash
brew upgrade terraform
terraform init
```

### Issue 5: Terraform Apply Fails

**Symptoms:**
- "Error creating resource"
- "Resource already exists"
- Connection timeout errors

**Diagnosis:**
```bash
# Check LocalStack is running
curl http://localhost:4566/_localstack/health

# Check Terraform state
terraform state list

# Enable debug logging
export TF_LOG=DEBUG
terraform apply
```

**Solutions:**

**Solution A: LocalStack Not Ready**
```bash
# Wait for LocalStack
sleep 10
terraform apply
```

**Solution B: Resource Already Exists**
```bash
# Import existing resource
terraform import aws_lambda_function.my_lambda my_lambda

# Or destroy and recreate
terraform destroy -target=aws_lambda_function.my_lambda
terraform apply
```

**Solution C: State Lock**
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

**Solution D: Clean State**
```bash
# Nuclear option: reset everything
terraform destroy -auto-approve
rm terraform.tfstate*
terraform apply -auto-approve
```

### Issue 6: Terraform State Drift

**Symptoms:**
- "Resource has been modified outside Terraform"
- Unexpected changes in plan

**Diagnosis:**
```bash
# Refresh state
terraform refresh

# Show current state
terraform show
```

**Solutions:**

**Solution A: Refresh State**
```bash
terraform refresh
terraform plan
```

**Solution B: Import Resources**
```bash
# Import manually created resources
terraform import aws_sqs_queue.my_queue my-queue
```

**Solution C: Reset State**
```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup.manual

# Destroy and recreate
terraform destroy
terraform apply
```

## 🔧 Lambda Issues

### Issue 7: Lambda Function Not Found

**Symptoms:**
- "Function not found: my_lambda"
- 404 errors when invoking

**Diagnosis:**
```bash
# List Lambda functions
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Check Terraform state
terraform state show aws_lambda_function.my_lambda
```

**Solutions:**

**Solution A: Redeploy Lambda**
```bash
terraform apply -replace=aws_lambda_function.my_lambda
```

**Solution B: Check Package**
```bash
# Verify ZIP file exists
ls -lh package/my_lambda.zip

# Verify ZIP contents
unzip -l package/my_lambda.zip | grep main.py
```

**Solution C: Recreate Package**
```bash
rm -rf package/
mkdir package
pip install -r requirements.txt -t ./package
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..
terraform apply -auto-approve
```

### Issue 8: Lambda Execution Errors

**Symptoms:**
- 500 Internal Server Error
- "Task timed out"
- "Module not found"

**Diagnosis:**
```bash
# Check Lambda logs (if available)
aws --endpoint-url=http://localhost:4566 logs tail /aws/lambda/my_lambda

# Test Lambda directly
aws --endpoint-url=http://localhost:4566 lambda invoke \
  --function-name my_lambda \
  --payload '{"body":"{\"test\":\"direct\"}"}' \
  response.json
cat response.json
```

**Solutions:**

**Solution A: Missing Dependencies**
```bash
# Reinstall dependencies
pip install -r requirements.txt -t ./package
cd package && zip -r my_lambda.zip . && cd ..
terraform apply -auto-approve
```

**Solution B: Increase Timeout**
```hcl
# In main.tf
resource "aws_lambda_function" "my_lambda" {
  timeout = 10  # Increase from 3 to 10 seconds
}
```

**Solution C: Check Environment Variables**
```bash
# Verify QUEUE_URL is set
aws --endpoint-url=http://localhost:4566 lambda get-function-configuration \
  --function-name my_lambda | jq .Environment
```

**Solution D: Fix Code Errors**
```python
# Add error handling in main.py
try:
    body = json.loads(event["body"])
except Exception as e:
    print(f"Error: {e}")
    return {
        "statusCode": 500,
        "body": json.dumps({"error": str(e)})
    }
```

## 🌐 API Gateway Issues

### Issue 9: API Gateway 403 Forbidden

**Symptoms:**
- 403 Forbidden error
- "Missing Authentication Token"

**Diagnosis:**
```bash
# Check API Gateway exists
aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis

# Get API ID
terraform output rest_api_id
```

**Solutions:**

**Solution A: Wrong URL Format**
```bash
# LocalStack requires _user_request_ in URL
# Wrong:
http://localhost:4566/restapis/abc123/dev/api/mylambda

# Correct:
http://localhost:4566/restapis/abc123/dev/_user_request_/api/mylambda

# Use Terraform output
API_URL=$(terraform output -raw invoke_url_localstack)
```

**Solution B: Redeploy API Gateway**
```bash
terraform apply -replace=aws_api_gateway_deployment.rest_deployment
```

### Issue 10: API Gateway 502 Bad Gateway

**Symptoms:**
- 502 Bad Gateway error
- "Internal server error"

**Diagnosis:**
```bash
# Check Lambda integration
aws --endpoint-url=http://localhost:4566 apigateway get-integration \
  --rest-api-id $(terraform output -raw rest_api_id) \
  --resource-id <resource-id> \
  --http-method POST
```

**Solutions:**

**Solution A: Check Lambda Permissions**
```bash
# Verify Lambda permission exists
terraform state show aws_lambda_permission.apigw_lambda
```

**Solution B: Redeploy Everything**
```bash
terraform destroy -auto-approve
terraform apply -auto-approve
```

## 📨 SQS Issues

### Issue 11: Messages Not Appearing in Queue

**Symptoms:**
- Lambda succeeds but no messages in SQS
- Empty receive-message response

**Diagnosis:**
```bash
# Check queue exists
aws --endpoint-url=http://localhost:4566 sqs list-queues

# Check queue attributes
aws --endpoint-url=http://localhost:4566 sqs get-queue-attributes \
  --queue-url $(terraform output -raw sqs_queue_url) \
  --attribute-names All
```

**Solutions:**

**Solution A: Check Queue URL**
```bash
# Verify Lambda has correct QUEUE_URL
aws --endpoint-url=http://localhost:4566 lambda get-function-configuration \
  --function-name my_lambda | jq .Environment.Variables.QUEUE_URL
```

**Solution B: Check IAM Permissions**
```bash
# Verify Lambda role has SQS permissions
terraform state show aws_iam_role_policy.lambda_policy
```

**Solution C: Test Direct Send**
```bash
# Send message directly to SQS
aws --endpoint-url=http://localhost:4566 sqs send-message \
  --queue-url $(terraform output -raw sqs_queue_url) \
  --message-body "test message"

# Receive message
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url $(terraform output -raw sqs_queue_url)
```

### Issue 12: Too Many Messages in Queue

**Symptoms:**
- Queue depth keeps growing
- Old messages not being processed

**Solutions:**

**Solution A: Purge Queue**
```bash
aws --endpoint-url=http://localhost:4566 sqs purge-queue \
  --queue-url $(terraform output -raw sqs_queue_url)
```

**Solution B: Set Up DLQ**
```hcl
# Add Dead Letter Queue in main.tf
resource "aws_sqs_queue" "dlq" {
  name = "my-queue-dlq"
}

resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}
```

## 🐍 Python/Dependencies Issues

### Issue 13: Module Not Found

**Symptoms:**
- "No module named 'boto3'"
- Import errors in Lambda

**Diagnosis:**
```bash
# Check package contents
unzip -l package/my_lambda.zip | grep boto3
```

**Solutions:**

**Solution A: Reinstall Dependencies**
```bash
rm -rf package/
mkdir package
pip install -r requirements.txt -t ./package
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..
```

**Solution B: Check Python Version**
```bash
# Ensure using correct Python version
python3 --version  # Should match Lambda runtime (3.12)

# Use specific Python version
python3.12 -m pip install -r requirements.txt -t ./package
```

**Solution C: Virtual Environment**
```bash
# Use virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -t ./package
```

## 🔄 General Troubleshooting Steps

### Step 1: Check All Services

```bash
# Run diagnostics
./check-health.sh

# Or manually:
docker ps
curl http://localhost:4566/_localstack/health
terraform state list
```

### Step 2: Check Logs

```bash
# LocalStack logs
docker-compose logs -f localstack

# Terraform debug
export TF_LOG=DEBUG
terraform apply
```

### Step 3: Clean Restart

```bash
# Nuclear option: reset everything
docker-compose down -v
rm -rf volume/
rm -rf .terraform/
rm terraform.tfstate*
rm -rf package/

# Start fresh
docker-compose up -d
sleep 30
pip install -r requirements.txt -t ./package
cp main.py ./package/
cd package && zip -r my_lambda.zip . && cd ..
terraform init
terraform apply -auto-approve
```

## 📞 Getting Help

### LocalStack Community

- **Slack**: https://localstack.cloud/slack
- **Discuss**: https://discuss.localstack.cloud/
- **GitHub Issues**: https://github.com/localstack/localstack/issues

### Useful Commands

```bash
# LocalStack version
docker exec localstack-main localstack --version

# LocalStack status
docker exec localstack-main localstack status

# LocalStack config
docker exec localstack-main localstack config show
```

### Debug Mode

```yaml
# Enable maximum logging
environment:
  - DEBUG=1
  - LS_LOG=trace
  - LAMBDA_EXECUTOR=local  # For easier debugging
```

---

**Next**: [Validation Results →](07-VALIDATION-RESULTS.md)  
**Previous**: [← Configuration](05-CONFIGURATION.md)