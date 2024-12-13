from mitmproxy import http
import json
from sqs import send_message
from configs import capturing_chat_metrics, capturing_ghost_text_metrics

def process_ghost_text_events(flow: http.HTTPFlow):
    request_body = flow.request.json()
    for item in request_body:
        name = item.get("data").get("baseData").get("name")
        if(name and name in capturing_ghost_text_metrics):
            machine_id = item.get("data").get("baseData").get("properties").get("client_machineid")
            datetime = item.get("time")
            print("Ghost text event name:", name)
            send_message({
                "machineId": machine_id,
                "eventName": name,
                "datetime": datetime
            })

def process_chat_events(flow: http.HTTPFlow):
    request_body = flow.request.content.decode('utf-8')
    for line in request_body.strip().splitlines():
        try:
            json_data = json.loads(line)
            name = json_data.get("data").get("baseData").get("name")
            if(name and name in capturing_chat_metrics):
                machine_id = json_data.get("data").get("baseData").get("properties").get("client_machineid")
                datetime = json_data.get("time")
                print("Chat event name:", name)
                send_message({
                "machineId": machine_id,
                "eventName": name,
                "datetime": datetime
                })
        except json.JSONDecodeError as e:
            print(f"Failed to parse line: {line}\nError: {e}")