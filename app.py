import json
import boto3
import logging
import os
from decimal import Decimal

# Setup logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB using environment variable
dynamodb = boto3.resource("dynamodb")
table_name = os.environ.get("TABLE_NAME")

if not table_name:
    raise Exception("TABLE_NAME environment variable not set")

table = dynamodb.Table(table_name)

def app_lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    try:
        resume_id = event.get("pathParameters", {}).get("id")

        if not resume_id:
            logger.warning("Missing resume id in request")
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing resume id"})
            }

        response = table.get_item(Key={"id": resume_id})

        if "Item" not in response:
            logger.info("Resume not found: %s", resume_id)
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "Resume not found"})
            }

        logger.info("Resume retrieved successfully: %s", resume_id)

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps(response["Item"], default=str)
        }

    except Exception as e:
        logger.error("Unhandled error", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"})
        }
