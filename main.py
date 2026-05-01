import json
import os
import boto3

# Initialize SQS client
sqs = boto3.client("sqs")

# Get queue URL from environment variable
QUEUE_URL = os.environ["QUEUE_URL"]

def handler(event, context):
    """
    Lambda handler triggered by API Gateway HTTP request.
    Expects JSON payload in the request body.
    """
    try:
        # Parse request body
        body = json.loads(event["body"])

        # Send message to SQS
        response = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(body)
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Payload sent to SQS successfully",
                "messageId": response["MessageId"]
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }
