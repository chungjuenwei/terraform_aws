def lambda_handler(event, context):
    # Simulate processing the result from the first Lambda
    result = {
        "status": "success",  # Change to "fail" to test the failure path
        "message": "Processed result: " + event["body"]
    }
    return result