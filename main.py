from mitmproxy import http
import json
import boto3

queue_url = "https://sqs.us-east-1.amazonaws.com/826406658508/copilot-events"

def send_message(message_body):
    # Create SQS client
    sqs = boto3.client('sqs')

    # Send message to SQS queue
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(message_body)  # Convert your message to a JSON string
    )

def request(flow: http.HTTPFlow) -> None:
    # Filter requests to the GitHub Copilot telemetry service endpoint
    if("copilot-telemetry-service.githubusercontent.com/telemetry" in flow.request.pretty_url):
        try:
            # Parse the request body as JSON (if possible)
            request_body = flow.request.json()

            # Debug: Print the parsed JSON to help with troubleshooting
            # loop through the items in request_body
            for item in request_body:
                name = item.get("data").get("baseData").get("name")
                # check if the name attribute present in the item and whether 
                if(name and name == "copilot/ghostText.accepted"):
                    machine_id = item.get("data").get("baseData").get("properties").get("client_machineid")
                    send_message({
                        "machineId": machine_id,
                        "eventName": name
                    })
        except Exception as e:
            print("Error occurred in handling the event:", e)

    # Allow other requests to proceed
    flow.resume()