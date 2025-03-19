def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "body": "Greetings from the Dev Lambda!",
        "headers": {
            "Content-Type": "text/plain"
        }
    }