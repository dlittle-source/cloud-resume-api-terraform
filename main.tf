data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda/lambda.zip"
}


resource "aws_lambda_function" "resume_api" {
  function_name = "resume-api"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.app_lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.resumes.name
    }
  }
}


# create an IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "resume-api-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# attach policies to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ddb_read" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}

# create DynamoDB table
resource "aws_dynamodb_table" "resumes" {
  name         = "resumes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# create API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "ResumeAPI"
}

# create resource resume
resource "aws_api_gateway_resource" "resume" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "resume"
}

# create resouce resume/{id}
resource "aws_api_gateway_resource" "resume_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.resume.id
  path_part   = "{id}"
}

# create GET method for resume/{id}
resource "aws_api_gateway_method" "get_resume" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resume_id.id
  http_method   = "GET"
  authorization = "NONE"
}

# integrate GET method with Lambda
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resume_id.id
  http_method             = aws_api_gateway_method.get_resume.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.resume_api.invoke_arn
}

# grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# deploy API Gateway
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.lambda
  ]
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

# Read JSON file
locals {
  resumes = jsondecode(file("${path.module}/seed/resume.json"))
}

# Create DynamoDB items
resource "aws_dynamodb_table_item" "resume_items" {
  for_each   = { for r in local.resumes : r.id => r }
  table_name = aws_dynamodb_table.resumes.name
  hash_key   = "id"

  item = jsonencode({
    id     = { S = each.value.id }
    name   = { S = each.value.name }
    title  = { S = each.value.title }
    skills = { S = each.value.skills }
  })
}


# Allow Lambda to write logs to CloudWatch
resource "aws_iam_policy" "lambda_logging" {
  name = "lambda-cloudwatch-logging"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach logging policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_logging_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}





