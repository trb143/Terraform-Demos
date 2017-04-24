resource "aws_iam_role_policy" "example_policy" {
  name = "example_policy"
  role = "${aws_iam_role.example_api_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "Stmt1493060054000",
          "Effect": "Allow",
          "Action": [
              "lambda:InvokeAsync",
              "lambda:InvokeFunction"
          ],
          "Resource": [
              "arn:aws:lambda:*:*:*"
          ]
      },
      {
          "Sid": "Stmt1493060108000",
          "Effect": "Allow",
          "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:DescribeLogStreams",
              "logs:PutLogEvents"
          ],
          "Resource": [
              "arn:aws:logs:*:*:*"
          ]
      }
  ]
}
EOF
}


resource "aws_iam_role" "example_api_role" {
  name = "example_api_role"
  assume_role_policy = "${file("policies/api-lambda-role.json")}"
}

data "archive_file" "api_lambda" {
  type = "zip"
  source_file = "./js/apiindex.js"
  output_path = "api-lambda.zip"
}

resource "aws_lambda_function" "example_test_function" {
  filename = "${data.archive_file.api_lambda.output_path}"
  function_name = "example_test_function"
  role = "${aws_iam_role.example_api_role.arn}"
  handler = "apiindex.handler"
  runtime = "nodejs4.3"
  source_code_hash = "${base64sha256(file("${data.archive_file.api_lambda.output_path}"))}"
  publish = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  function_name = "${aws_lambda_function.example_test_function.arn}"
  statement_id = "AllowExecutionFromApiGateway"
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.example_api.id}/*/${aws_api_gateway_method.example_api_method.http_method}${aws_api_gateway_resource.example_api_resource.path}"
}

resource "aws_api_gateway_rest_api" "example_api" {
  name = "ExampleAPI"
  description = "Example Rest Api"
}

resource "aws_api_gateway_resource" "example_api_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.example_api.id}"
  parent_id = "${aws_api_gateway_rest_api.example_api.root_resource_id}"
  path_part = "messages"
}

resource "aws_api_gateway_method" "example_api_method" {
  rest_api_id = "${aws_api_gateway_rest_api.example_api.id}"
  resource_id = "${aws_api_gateway_resource.example_api_resource.id}"
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example_api_method-integration" {
  rest_api_id = "${aws_api_gateway_rest_api.example_api.id}"
  resource_id = "${aws_api_gateway_resource.example_api_resource.id}"
  http_method = "${aws_api_gateway_method.example_api_method.http_method}"
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.example_test_function.function_name}/invocations"
  integration_http_method = "POST"
}

resource "aws_api_gateway_deployment" "example_deployment_dev" {
  depends_on = [
    "aws_api_gateway_method.example_api_method",
    "aws_api_gateway_integration.example_api_method-integration"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.example_api.id}"
  stage_name = "dev"
}

resource "aws_api_gateway_deployment" "example_deployment_prod" {
  depends_on = [
    "aws_api_gateway_method.example_api_method",
    "aws_api_gateway_integration.example_api_method-integration"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.example_api.id}"
  stage_name = "api"
}

output "dev_url" {
  value = "https://${aws_api_gateway_deployment.example_deployment_dev.rest_api_id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.example_deployment_dev.stage_name}"
}

output "prod_url" {
  value = "https://${aws_api_gateway_deployment.example_deployment_prod.rest_api_id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.example_deployment_prod.stage_name}"
}
