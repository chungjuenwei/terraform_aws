# Step Function IAM Role
resource "aws_iam_role" "step_function_role" {
  name = "step_function_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "step_function_policy"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Lambda Function (Python)
resource "aws_lambda_function" "hello_lambda" {
  filename      = "./aws_step_function/hello_lambda.zip"   # file to be uploaded
  function_name = "hello_lambda"    # lambda function name to be created in lambda console
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler" # Python handler format: <python_filename>.<function_name>
  runtime       = "python3.12"

  source_code_hash = filebase64sha256("./aws_step_function/hello_lambda.zip")
}

# 2nd Lambda Step
resource "aws_lambda_function" "process_result_lambda" {
  filename      = "./aws_step_function/process_result_lambda.zip"
  function_name = "process_result_lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "process_result_lambda.lambda_handler"
  runtime       = "python3.12"

  source_code_hash = filebase64sha256("./aws_step_function/process_result_lambda.zip")
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "MyStepFunction"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
{
  "Comment": "A Step Function with 3 steps: HelloWorld, ProcessResult, and Choice",
  "StartAt": "HelloWorld",
  "States": {
    "HelloWorld": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.hello_lambda.arn}",
      "Next": "ProcessResult"
    },
    "ProcessResult": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.process_result_lambda.arn}",
      "Next": "CheckResult"
    },
    "CheckResult": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.status",
          "StringEquals": "success",
          "Next": "SuccessState"
        }
      ],
      "Default": "FailState"
    },
    "SuccessState": {
      "Type": "Pass",
      "Result": "Workflow completed successfully!",
      "End": true
    },
    "FailState": {
      "Type": "Pass",
      "Result": "Workflow failed!",
      "End": true
    }
  }
}
EOF
}

output "step_function_arn" {
  value = aws_sfn_state_machine.sfn_state_machine.id
}
