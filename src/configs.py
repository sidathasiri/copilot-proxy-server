queue_url = "https://sqs.us-east-1.amazonaws.com/826406658508/copilot-events"

# Metrics
capturing_ghost_text_metrics = ["copilot/ghostText.shown", "copilot/ghostText.shownFromCache", "copilot/ghostText.accepted"]
capturing_chat_metrics = ["GitHub.copilot-chat/inlineConversation.message", "GitHub.copilot-chat/inlineConversation.accept", "GitHub.copilot-chat/inlineConversation.undo"]

print(queue_url)