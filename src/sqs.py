import boto3
import json
from configs import queue_url

def send_message(message_body):
    # Create SQS client
    sqs = boto3.client('sqs')

    # Send message to SQS queue
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(message_body)  # Convert your message to a JSON string
    )