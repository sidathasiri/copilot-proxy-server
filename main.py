from mitmproxy import http
import json
import os

# Get the directory where the script is located
script_dir = os.path.dirname(os.path.abspath(__file__))

# Define the file path for the JSON log file
log_file_path = os.path.join(script_dir, "telemetry_log.json")

def log_request_payload(name, machineId) -> None:
    """Append the request payload to a single JSON file with separation."""
    # Prepare the log entry with a timestamp
    log_entry = {
        "name": name,
        "machineId": machineId
    }
    
    # Append the log entry to the file
    with open(log_file_path, "a") as log_file:
        log_file.write(json.dumps(log_entry, indent=4))
        log_file.write(",\n")  # Add a comma and newline for separation

def request(flow: http.HTTPFlow) -> None:
    # Filter requests to the GitHub Copilot telemetry service endpoint
    if "copilot-telemetry-service.githubusercontent.com/telemetry" in flow.request.pretty_url:
        try:
            # Parse the request body as JSON (if possible)
            request_body = flow.request.json()

            # Debug: Print the parsed JSON to help with troubleshooting
            # loop through the items in request_body
            for item in request_body:
                name = item.get("data").get("baseData").get("name")
                # check if the name attribute present in the item and whether 
                if(name and name == "copilot/ghostText.accepted"):
                    machineId = item.get("data").get("baseData").get("properties").get("client_machineid")
                    log_request_payload(name, machineId)
        
            


        except ValueError:
            # If the body is not JSON, store it as plain text
            request_body = {"raw_text": flow.request.get_text()}
            # Optional: Log raw text if desired, but generally you might ignore non-JSON payloads
            print("Non-JSON payload:", request_body)
    
    # Allow other requests to proceed
    flow.resume()