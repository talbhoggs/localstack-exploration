# Architecture Overview

## 📊 System Architecture

![LocalStack Architecture](images/architecture.png)

## 🏗️ High-Level Design

This project implements a **serverless event-driven architecture** using AWS services, running entirely on LocalStack for local development.

### Architecture Pattern

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

## 🔄 Request Flow

### 1. Client Request
- **Action**: Client sends HTTP POST request with JSON payload
- **Endpoint**: `/api/mylambda`
- **Method**: POST
- **Content-Type**: application/json

### 2. API Gateway Processing
- **Action**: Receives and validates request
- **Integration**: AWS_PROXY with Lambda
- **Stage**: dev
- **Authentication**: None (for validation purposes)

### 3. Lambda Execution
- **Action**: Processes request and sends to SQS
- **Runtime**: Python 3.12
- **Handler**: `main.handler`
- **Environment**: QUEUE_URL injected

### 4. SQS Storage
- **Action**: Stores message for downstream processing
- **Queue Type**: Standard Queue
- **Persistence**: LocalStack volume

### 5. Response
- **Action**: Returns success/error to client
- **Status**: 200 OK or 500 Error
- **Body**: JSON with message ID or error details

## 🧩 Components

### 1. API Gateway (REST API)

**Purpose**: HTTP endpoint for client requests

**Configuration:**
- **Name**: MyRestApi
- **Type**: REST API (v1)
- **Resource Path**: `/api/mylambda`
- **Method**: POST
- **Authorization**: NONE
- **Integration**: AWS_PROXY

**LocalStack URL Format:**
```
http://localhost:4566/restapis/{api-id}/dev/_user_request_/api/mylambda
```

**AWS Production URL Format:**
```
https://{api-id}.execute-api.us-east-1.amazonaws.com/dev/api/mylambda
```

### 2. Lambda Function

**Purpose**: Business logic processor

**Configuration:**
- **Function Name**: my_lambda
- **Runtime**: Python 3.12
- **Handler**: main.handler
- **Memory**: 128 MB (default)
- **Timeout**: 3 seconds (default)
- **Package**: my_lambda.zip

**Environment Variables:**
```python
QUEUE_URL = "http://localhost:4566/000000000000/my-queue"
```

**Code Structure:**
```python
def handler(event, context):
    # 1. Parse request body
    body = json.loads(event["body"])
    
    # 2. Send to SQS
    response = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(body)
    )
    
    # 3. Return response
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Success",
            "messageId": response["MessageId"]
        })
    }
```

### 3. SQS Queue

**Purpose**: Asynchronous message storage and decoupling

**Configuration:**
- **Queue Name**: my-queue
- **Type**: Standard Queue
- **Visibility Timeout**: 30 seconds (default)
- **Message Retention**: 4 days (default)
- **Maximum Message Size**: 256 KB (default)

**Use Cases:**
- Decouple Lambda from downstream processing
- Buffer messages during high load
- Enable asynchronous processing
- Provide message persistence

### 4. IAM Role & Policy

**Purpose**: Security and permissions management

**Role Configuration:**
```json
{
  "Role": "lambda_exec_role",
  "AssumeRolePolicy": {
    "Service": "lambda.amazonaws.com"
  }
}
```

**Policy Permissions:**
```json
{
  "Statement": [
    {
      "Action": ["sqs:SendMessage"],
      "Effect": "Allow",
      "Resource": "arn:aws:sqs:us-east-1:000000000000:my-queue"
    },
    {
      "Action": ["logs:*"],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
```

**Note**: CloudWatch Logs permissions are granted but logs are not explicitly configured in Terraform.

## 🔐 Security Model

### Authentication & Authorization

**Current Setup (Validation):**
- ✅ IAM roles for Lambda execution
- ✅ Least privilege permissions
- ❌ No API Gateway authentication (intentional for testing)
- ❌ No encryption at rest (LocalStack limitation)

**Production Recommendations:**
- Add API Gateway authentication (API Keys, Cognito, or IAM)
- Enable encryption for SQS messages
- Implement request validation
- Add rate limiting
- Enable CloudWatch Logs

## 📦 Data Flow

### Request Payload Example

```json
{
  "userId": "user123",
  "action": "purchase",
  "items": [
    {"id": "item1", "quantity": 2},
    {"id": "item2", "quantity": 1}
  ],
  "timestamp": "2026-05-01T09:00:00Z"
}
```

### API Gateway Event Structure

```json
{
  "body": "{\"userId\":\"user123\",...}",
  "headers": {
    "Content-Type": "application/json"
  },
  "httpMethod": "POST",
  "path": "/api/mylambda",
  "queryStringParameters": null,
  "requestContext": {...}
}
```

### SQS Message Structure

```json
{
  "MessageId": "12345678-1234-1234-1234-123456789012",
  "Body": "{\"userId\":\"user123\",...}",
  "MD5OfBody": "...",
  "ReceiptHandle": "..."
}
```

### Lambda Response Structure

```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"message\":\"Payload sent to SQS successfully\",\"messageId\":\"...\"}"
}
```

## 🎯 Design Decisions

### Why This Architecture?

1. **Decoupling**: Lambda and downstream processing are independent
2. **Scalability**: SQS buffers messages during high load
3. **Reliability**: Messages persist even if processing fails
4. **Simplicity**: Minimal components for validation
5. **Cost-Effective**: Pay-per-use model (in production)

### LocalStack vs AWS Differences

| Aspect | LocalStack | AWS Production |
|--------|-----------|----------------|
| **URL Format** | Includes `_user_request_` | Clean REST URL |
| **Endpoint** | localhost:4566 | AWS regional endpoints |
| **Authentication** | Test credentials | Real IAM credentials |
| **Persistence** | Local volume | Cloud storage |
| **Performance** | Faster (local) | Network latency |
| **Cost** | Free | Pay-per-use |

## 🔄 Scalability Considerations

### Current Limitations (Validation Setup)

- Single LocalStack instance
- No auto-scaling
- No load balancing
- No multi-region support

### Production Scaling Strategy

1. **API Gateway**: Auto-scales automatically
2. **Lambda**: Concurrent execution limits
3. **SQS**: Unlimited throughput (standard queue)
4. **Monitoring**: CloudWatch metrics and alarms

## 📈 Performance Characteristics

### Expected Latency (LocalStack)

- API Gateway → Lambda: <10ms
- Lambda execution: 50-100ms
- SQS send message: <10ms
- Total end-to-end: <150ms

### Expected Latency (AWS Production)

- API Gateway → Lambda: 10-50ms
- Lambda cold start: 100-500ms
- Lambda warm execution: 50-200ms
- SQS send message: 10-50ms
- Total end-to-end: 200-800ms

## 🔍 Monitoring & Observability

### Available Metrics (LocalStack)

- Lambda invocation count
- Lambda error count
- SQS message count
- API Gateway request count

### Recommended Production Metrics

- API Gateway 4xx/5xx errors
- Lambda duration and memory usage
- SQS queue depth and age
- Custom business metrics

## 🎓 Architecture Patterns

This implementation demonstrates:

- ✅ **Event-Driven Architecture**: Asynchronous message processing
- ✅ **Serverless Pattern**: No server management
- ✅ **Microservices**: Single-purpose Lambda function
- ✅ **API Gateway Pattern**: HTTP to Lambda integration
- ✅ **Queue-Based Load Leveling**: SQS buffers requests

## 🔄 Extension Points

### Easy to Add

- Additional API endpoints
- More Lambda functions
- Additional SQS queues
- DynamoDB for state storage
- S3 for file storage

### Requires More Work

- Authentication/Authorization
- Multi-region deployment
- Advanced monitoring
- CI/CD pipeline
- Production-grade error handling

---

**Next**: [Deployment Guide →](03-DEPLOYMENT.md)  
**Previous**: [← Getting Started](01-GETTING-STARTED.md)