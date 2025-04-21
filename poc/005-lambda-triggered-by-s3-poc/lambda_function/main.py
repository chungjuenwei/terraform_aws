import json

def lambda_handler(event, context):
    print("Lambda triggered by S3 event!")
    
    # Process each S3 record in the event
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        size = record['s3']['object'].get('size', 'N/A')
        
        print(f"New file uploaded to S3!")
        print(f"Bucket: {bucket}")
        print(f"File: {key}")
        print(f"Size: {size} bytes")
    
    return {
        'statusCode': 200,
        'body': json.dumps('S3 Event Processed Successfully!')
    }