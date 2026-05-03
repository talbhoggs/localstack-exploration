# Getting Started with LocalStack

## 📦 Prerequisites

### Required Software

#### 1. Docker Desktop
```bash
# Verify installation
docker --version
# Should be >= 20.10

# Check Docker is running
docker ps
```

**Installation:**
- macOS: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
- Windows: [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

#### 2. Terraform
```bash
# Install via Homebrew (macOS)
brew install terraform

# Or download from: https://www.terraform.io/downloads

# Verify installation
terraform --version
# Should be >= 1.0
```

#### 3. AWS CLI
```bash
# Install via Homebrew (macOS)
brew install awscli

# Or follow: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Verify installation
aws --version
# Should be >= 2.0
```

#### 4. Python
```bash
# Verify installation
python3 --version
# Should be >= 3.8

# Verify pip
pip3 --version
```

### Optional: LocalStack Account

While not required, a LocalStack account provides:
- Extended service support
- Better performance
- Community features

1. Sign up at [LocalStack](https://app.localstack.cloud/)
2. Get your authentication token
3. Update `docker-compose.yaml` with your token

## 🚀 Quick Start (5 Minutes)

### Step 1: Clone or Navigate to Project

```bash
cd /path/to/localstack
```

### Step 2: Start LocalStack

```bash
# Start LocalStack container
docker-compose up -d

# Verify it's running
docker-compose ps

# Check logs
docker-compose logs -f localstack
```

**Wait for this message in logs**: `Ready.`

### Step 3: Verify LocalStack Services

```bash
# Check health endpoint
curl http://localhost:4566/_localstack/health

# Expected output shows available services
{
  "services": {
    "apigateway": "available",
    "lambda": "available",
    "sqs": "available",
    "iam": "available",
    ...
  }
}
```

### Step 4: Package Lambda Function

```bash
# Create package directory (if not exists)
mkdir -p package

# Install dependencies
pip install -r requirements.txt -t ./package

# Copy Lambda handler
cp main.py ./package/

# Create deployment package
cd package
zip -r my_lambda.zip .
cd ..
```

### Step 5: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes (basic method)
terraform plan

# Deploy (basic method)
terraform apply -auto-approve
```

#### Best Practice: Using Plan Files

For production-grade deployments, use plan files:

```bash
# Generate execution plan with detailed exit codes
terraform plan -out=tfplan -detailed-exitcode

# Apply the exact plan that was reviewed
terraform apply "tfplan"

# Clean up
rm tfplan
```

**Why use plan files?**
- ✅ Ensures consistency between plan and apply
- ✅ Prevents accidental changes in team environments
- ✅ Enables automated CI/CD pipelines
- ✅ Provides audit trail of changes

**Expected output:**
```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
rest_api_id = "abc123xyz"
invoke_url_localstack = "http://localhost:4566/restapis/abc123xyz/dev/_user_request_/api/mylambda"
sqs_queue_url = "http://localhost:4566/000000000000/my-queue"
```

### Step 6: Test the API

```bash
# Get API endpoint
API_URL=$(terraform output -raw invoke_url_localstack)

# Send test request
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"validation","timestamp":"2026-05-01T09:00:00Z"}'

# Expected response:
{
  "message": "Payload sent to SQS successfully",
  "messageId": "12345678-1234-1234-1234-123456789012"
}
```

### Step 7: Verify SQS Message

```bash
# Receive message from queue
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://localhost:4566/000000000000/my-queue

# Expected output shows your message
{
  "Messages": [
    {
      "MessageId": "...",
      "Body": "{\"test\":\"validation\",\"timestamp\":\"2026-05-01T09:00:00Z\"}"
    }
  ]
}
```

## ✅ Verification Checklist

- [ ] Docker is running
- [ ] LocalStack container is up
- [ ] Health endpoint returns available services
- [ ] Lambda package created successfully
- [ ] Terraform apply completed without errors
- [ ] API endpoint returns 200 OK
- [ ] Message appears in SQS queue

## 🎉 Success!

You've successfully:
1. ✅ Started LocalStack
2. ✅ Deployed AWS infrastructure locally
3. ✅ Tested the serverless API
4. ✅ Verified message processing

## 🔄 Next Steps

- **[Architecture Guide](02-ARCHITECTURE.md)** - Understand the system design
- **[Deployment Guide](03-DEPLOYMENT.md)** - Detailed deployment procedures
- **[Testing Guide](04-TESTING.md)** - Comprehensive testing scenarios
- **[Configuration](05-CONFIGURATION.md)** - Customize your setup

## 🛑 Stopping LocalStack

```bash
# Stop container
docker-compose stop

# Stop and remove container
docker-compose down

# Stop and remove all data
docker-compose down -v
rm -rf volume/
```

## 🔧 Troubleshooting

If you encounter issues, see the [Troubleshooting Guide](06-TROUBLESHOOTING.md).

### Common Quick Fixes

**LocalStack won't start:**
```bash
docker-compose down
docker-compose up -d
```

**Port 4566 already in use:**
```bash
# Find process using port
lsof -i :4566
# Kill the process or change port in docker-compose.yaml
```

**Terraform errors:**
```bash
# Reinitialize
rm -rf .terraform/
terraform init
```

---

**Next**: [Architecture Guide →](02-ARCHITECTURE.md)