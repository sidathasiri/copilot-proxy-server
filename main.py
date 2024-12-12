from mitmproxy import http
import json
import boto3

queue_url = "https://sqs.us-east-1.amazonaws.com/826406658508/copilot-events"
capturing_metrics = ["copilot/ghostText.shown", "copilot/ghostText.shownFromCache", "copilot/ghostText.accepted"]

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
    if("telemetry.individual.githubcopilot.com/telemetry" in flow.request.pretty_url):
        try:
            # Parse the request body as JSON (if possible)
            request_body = flow.request.json()

            # Debug: Print the parsed JSON to help with troubleshooting
            # loop through the items in request_body
            for item in request_body:
                name = item.get("data").get("baseData").get("name")
                # check if the name attribute present in the item and whether 
                if(name and name in capturing_metrics):
                    machine_id = item.get("data").get("baseData").get("properties").get("client_machineid")
                    datetime = item.get("time")
                    send_message({
                        "machineId": machine_id,
                        "eventName": name,
                        "datetime": datetime
                    })
        except Exception as e:
            print("Error occurred in handling the event:", e)

    # Allow other requests to proceed
    flow.resume()