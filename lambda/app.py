import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("resumes")

def handler(event, context):
    path_params = event.get("pathParameters") or {}
    resume_id = path_params.get("id")

    if not resume_id:
        return {
            "statusCode": 400,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": "Missing resume id"})
        }

    response = table.get_item(Key={"id": resume_id})

    if "Item" not in response:
        return {
            "statusCode": 404,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": "Resume not found"})
        }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(response["Item"])
    }
