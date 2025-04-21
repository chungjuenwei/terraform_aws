import os

def lambda_handler(event, context):
    function_type = os.environ['FUNCTION_TYPE']
    stage = os.environ['STAGE']
    return {
        'statusCode': 200,
        'body': f'Hello from {function_type} in {stage}'
    }