# Testing Guide

## 🧪 Testing Overview

This guide covers comprehensive testing procedures for the LocalStack serverless application.

## 📋 Test Categories

1. **Smoke Tests** - Basic functionality verification
2. **Integration Tests** - End-to-end flow testing
3. **Error Handling Tests** - Failure scenarios
4. **Performance Tests** - Response time validation
5. **Data Validation Tests** - Payload verification

## 🚀 Quick Test Suite

### Run All Tests

```bash
# Set environment variables
export API_URL=$(terraform output -raw invoke_url_localstack)
export QUEUE_URL=$(terraform output -raw sqs_queue_url)

# Run test suite
./run-tests.sh
```

## Test 1: Basic API Request

### Purpose
Verify API Gateway and Lambda integration works.

### Test Command

```bash
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"basic","timestamp":"2026-05-01T09:00:00Z"}'
```

### Expected Response

```json
{
  "message": "Payload sent to SQS successfully",
  "messageId": "12345678-1234-1234-1234-123456789012"
}
```

### Validation
- ✅ Status code: 200
- ✅ Response contains `message` field
- ✅ Response contains `messageId` field
- ✅ MessageId is valid UUID format

## Test 2: Complex Payload

### Purpose
Verify Lambda handles complex JSON structures.

### Test Command

```bash
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "action": "purchase",
    "items": [
      {"id": "item1", "name": "Product A", "quantity": 2, "price": 29.99},
      {"id": "item2", "name": "Product B", "quantity": 1, "price": 49.99}
    ],
    "total": 109.97,
    "currency": "USD",
    "timestamp": "2026-05-01T09:00:00Z",
    "metadata": {
      "source": "web",
      "campaign": "spring-sale"
    }
  }'
```

### Expected Response

```json
{
  "message": "Payload sent to SQS successfully",
  "messageId": "..."
}
```

### Validation
- ✅ Status code: 200
- ✅ Complex nested objects handled correctly
- ✅ Arrays processed properly
- ✅ Numbers preserved (not converted to strings)

## Test 3: SQS Message Verification

### Purpose
Verify messages are correctly stored in SQS.

### Test Command

```bash
# Send message
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"sqs-verification","id":"test-123"}'

# Receive message from queue
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --max-number-of-messages 10
```

### Expected Response

```json
{
  "Messages": [
    {
      "MessageId": "...",
      "ReceiptHandle": "...",
      "MD5OfBody": "...",
      "Body": "{\"test\":\"sqs-verification\",\"id\":\"test-123\"}"
    }
  ]
}
```

### Validation
- ✅ Message appears in queue
- ✅ Message body matches sent payload
- ✅ Message ID is valid
- ✅ Receipt handle is present

## Test 4: Error Handling - Invalid JSON

### Purpose
Verify Lambda handles malformed JSON gracefully.

### Test Command

```bash
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d 'invalid json here'
```

### Expected Response

```json
{
  "error": "Expecting value: line 1 column 1 (char 0)"
}
```

### Validation
- ✅ Status code: 500
- ✅ Error message is descriptive
- ✅ No Lambda crash
- ✅ No message sent to SQS

## Test 5: Error Handling - Missing Content-Type

### Purpose
Verify API handles missing headers.

### Test Command

```bash
curl -X POST "$API_URL" \
  -d '{"test":"no-content-type"}'
```

### Expected Response

Should still work or return appropriate error.

### Validation
- ✅ Graceful handling
- ✅ Clear error message if rejected

## Test 6: Large Payload

### Purpose
Test Lambda with larger payloads.

### Test Command

```bash
# Generate large payload
python3 << 'EOF'
import json
import requests

payload = {
    "test": "large-payload",
    "data": ["item" + str(i) for i in range(1000)]
}

response = requests.post(
    "$API_URL",
    json=payload,
    headers={"Content-Type": "application/json"}
)

print(f"Status: {response.status_code}")
print(f"Response: {response.json()}")
EOF
```

### Validation
- ✅ Handles 1000+ array items
- ✅ No timeout errors
- ✅ Message successfully sent to SQS

## Test 7: Concurrent Requests

### Purpose
Test Lambda handles multiple simultaneous requests.

### Test Command

```bash
# Send 10 concurrent requests
for i in {1..10}; do
  curl -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"test\":\"concurrent\",\"id\":$i}" &
done
wait

# Check all messages in queue
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --max-number-of-messages 10
```

### Validation
- ✅ All 10 requests succeed
- ✅ All 10 messages in queue
- ✅ No duplicate messages
- ✅ No lost messages

## Test 8: Response Time

### Purpose
Measure API response time.

### Test Command

```bash
# Measure response time
time curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"performance"}' \
  -w "\nTime: %{time_total}s\n"
```

### Expected Performance

- ✅ Response time < 200ms (LocalStack)
- ✅ Consistent response times
- ✅ No timeouts

## Test 9: Lambda Logs (Optional)

### Purpose
Verify Lambda execution logs (if available).

### Test Command

```bash
# List log groups
aws --endpoint-url=http://localhost:4566 logs describe-log-groups

# Get log streams
aws --endpoint-url=http://localhost:4566 logs describe-log-streams \
  --log-group-name /aws/lambda/my_lambda

# Read logs
aws --endpoint-url=http://localhost:4566 logs tail \
  /aws/lambda/my_lambda --follow
```

### Validation
- ✅ Log group exists (if LocalStack creates it)
- ✅ Execution logs visible
- ✅ No error messages in logs

## Test 10: Queue Purge and Retest

### Purpose
Clean queue and verify fresh messages.

### Test Command

```bash
# Purge queue
aws --endpoint-url=http://localhost:4566 sqs purge-queue \
  --queue-url "$QUEUE_URL"

# Send new message
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"after-purge"}'

# Verify only new message exists
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url "$QUEUE_URL"
```

### Validation
- ✅ Queue purged successfully
- ✅ Only new message in queue
- ✅ Old messages removed

## 🐍 Python Test Script

Create `test_api.py`:

```python
#!/usr/bin/env python3
import requests
import json
import sys
import time

API_URL = "http://localhost:4566/restapis/YOUR_API_ID/dev/_user_request_/api/mylambda"

def test_basic_request():
    """Test 1: Basic API request"""
    print("Test 1: Basic API request...")
    
    payload = {"test": "basic", "timestamp": "2026-05-01T09:00:00Z"}
    response = requests.post(API_URL, json=payload)
    
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "message" in data, "Response missing 'message' field"
    assert "messageId" in data, "Response missing 'messageId' field"
    
    print("✅ Test 1 passed")
    return True

def test_complex_payload():
    """Test 2: Complex payload"""
    print("Test 2: Complex payload...")
    
    payload = {
        "userId": "user123",
        "items": [
            {"id": "item1", "quantity": 2},
            {"id": "item2", "quantity": 1}
        ],
        "metadata": {"source": "test"}
    }
    
    response = requests.post(API_URL, json=payload)
    assert response.status_code == 200
    
    print("✅ Test 2 passed")
    return True

def test_invalid_json():
    """Test 3: Invalid JSON handling"""
    print("Test 3: Invalid JSON handling...")
    
    response = requests.post(
        API_URL,
        data="invalid json",
        headers={"Content-Type": "application/json"}
    )
    
    assert response.status_code == 500, "Expected error status"
    data = response.json()
    assert "error" in data, "Response should contain error message"
    
    print("✅ Test 3 passed")
    return True

def test_performance():
    """Test 4: Response time"""
    print("Test 4: Response time...")
    
    payload = {"test": "performance"}
    
    start = time.time()
    response = requests.post(API_URL, json=payload)
    duration = time.time() - start
    
    assert response.status_code == 200
    assert duration < 1.0, f"Response too slow: {duration}s"
    
    print(f"✅ Test 4 passed (Response time: {duration:.3f}s)")
    return True

def test_concurrent_requests():
    """Test 5: Concurrent requests"""
    print("Test 5: Concurrent requests...")
    
    import concurrent.futures
    
    def send_request(i):
        payload = {"test": "concurrent", "id": i}
        response = requests.post(API_URL, json=payload)
        return response.status_code == 200
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(send_request, range(10)))
    
    assert all(results), "Some concurrent requests failed"
    
    print("✅ Test 5 passed")
    return True

def run_all_tests():
    """Run all tests"""
    print("=" * 50)
    print("Running LocalStack API Tests")
    print("=" * 50)
    
    tests = [
        test_basic_request,
        test_complex_payload,
        test_invalid_json,
        test_performance,
        test_concurrent_requests
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
        except Exception as e:
            print(f"❌ {test.__name__} failed: {e}")
            failed += 1
    
    print("=" * 50)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 50)
    
    return failed == 0

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
```

### Run Python Tests

```bash
# Update API_URL in script
vim test_api.py

# Run tests
python3 test_api.py
```

## 📊 Test Results Template

| Test | Status | Response Time | Notes |
|------|--------|---------------|-------|
| Basic Request | ✅ | 45ms | - |
| Complex Payload | ✅ | 52ms | - |
| SQS Verification | ✅ | - | Message received |
| Invalid JSON | ✅ | 38ms | Error handled |
| Large Payload | ✅ | 120ms | 1000 items |
| Concurrent (10) | ✅ | 180ms | All succeeded |
| Performance | ✅ | <200ms | Acceptable |

## 🎯 Test Checklist

- [ ] All smoke tests pass
- [ ] Integration tests pass
- [ ] Error handling works correctly
- [ ] Performance meets requirements
- [ ] Concurrent requests handled
- [ ] SQS messages verified
- [ ] No errors in logs
- [ ] Response times acceptable

## 🔄 Continuous Testing

### Watch Mode

```bash
# Continuously test API
watch -n 5 'curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "{\"test\":\"watch\",\"time\":\"$(date +%s)\"}"'
```

### Automated Testing

Add to CI/CD pipeline:

```yaml
# .github/workflows/test.yml
name: Test LocalStack
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Start LocalStack
        run: docker-compose up -d
      - name: Deploy
        run: terraform apply -auto-approve
      - name: Run Tests
        run: python3 test_api.py
```

---

**Next**: [Configuration →](05-CONFIGURATION.md)  
**Previous**: [← Deployment](03-DEPLOYMENT.md)