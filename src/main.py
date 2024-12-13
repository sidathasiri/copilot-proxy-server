from mitmproxy import http
from event_handler import process_chat_events, process_ghost_text_events

def request(flow: http.HTTPFlow) -> None:
    if("telemetry.individual.githubcopilot.com/telemetry" in flow.request.pretty_url):
        try:
            contentType = flow.request.headers.get("content-type")
            if(contentType == "application/json"):
                process_ghost_text_events(flow)
                
            elif(contentType == "application/x-json-stream"):
                process_chat_events(flow)
        except Exception as e:
            print("Error occurred in handling the event:", e)

    # Allow other requests to proceed
    flow.resume()