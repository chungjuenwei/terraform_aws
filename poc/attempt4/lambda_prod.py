def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "body": "Welcome from the Prod Lambda!",
        "headers": {
            "Content-Type": "text/plain"
        }
    }