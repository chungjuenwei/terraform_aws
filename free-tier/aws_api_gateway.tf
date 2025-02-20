# Create API Gateway
resource "aws_api_gateway_rest_api" "example_api" {
  name        = "MyExampleAPI"
  description = "Example API Gateway for AWS Free Tier"
}

# Create Resource (i.e., API Endpoint: /hello)
resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  parent_id   = aws_api_gateway_rest_api.example_api.root_resource_id
  path_part   = "hello"
}

# Create Method (GET /hello)
resource "aws_api_gateway_method" "hello_get" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "GET"
  authorization = "NONE"  # No authentication required
}

# Mock Integration (Returns a fixed response)
resource "aws_api_gateway_integration" "hello_mock" {
  rest_api_id             = aws_api_gateway_rest_api.example_api.id
  resource_id             = aws_api_gateway_resource.hello.id
  http_method             = aws_api_gateway_method.hello_get.http_method
  type                    = "MOCK"
  passthrough_behavior = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Method Response (Define expected response)
resource "aws_api_gateway_method_response" "hello_method_response" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.hello_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  # Add this block to allow the Content-Type header
  response_parameters = {
    "method.response.header.Content-Type" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }

}

# Integration Response (Define fixed response)
resource "aws_api_gateway_integration_response" "hello_response" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.hello_get.http_method
  status_code = "200"

  # Required for MOCK integrations
  selection_pattern = "200"

  response_templates = {
    "application/json" = "{\"message\": \"Hello from API Gateway!\"}"
  }

  # Add this block to set the Content-Type header
  response_parameters = {
    "method.response.header.Content-Type" = "'application/json'",
    "method.response.header.Access-Control-Allow-Origin" = "'*'" # Allow all origins
  }

  depends_on = [aws_api_gateway_integration.hello_mock]  # Ensure integration exists first
}


# Deploy API Gateway
resource "aws_api_gateway_deployment" "example_deployment" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id

  # Force redeployment when any of these resources change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.hello_mock,
      aws_api_gateway_method_response.hello_method_response,
      aws_api_gateway_integration_response.hello_response
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.hello_mock,
    aws_api_gateway_method_response.hello_method_response,
    aws_api_gateway_integration_response.hello_response
  ]

  lifecycle {
    create_before_destroy = true  # Critical for zero-downtime updates
  }

}


# Update your stage to enable logging
resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  stage_name    = "test"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format          = jsonencode({
      requestId     = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      caller        = "$context.identity.caller"
      user          = "$context.identity.user"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      resourcePath  = "$context.resourcePath"
      status        = "$context.status"
      protocol      = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  # Explicitly depend on the NEW deployment
  depends_on = [aws_api_gateway_deployment.example_deployment]

}


# Output the API URL
output "aws_api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.example_api.id}.execute-api.ap-southeast-1.amazonaws.com/test/hello"
}


### LOGS FOR DEBUGGING

resource "aws_api_gateway_account" "demo" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_iam_role" "cloudwatch" {
  name = "api_gateway_cloudwatch_global"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "default"
  role = aws_iam_role.cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}



resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.example_api.id}/test"
  retention_in_days = 7
}