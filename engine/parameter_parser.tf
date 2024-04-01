# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
resource "random_string" "random_suffix_02" {
  length  = 5
  special = false
  upper   = true
}

resource "aws_lambda_function" "parameter_parser" {
  filename      = data.archive_file.parameter_parser.output_path
  function_name = "ServiceCatalogTerraformCloudParameterParser"
  role          = aws_iam_role.parameter_parser.arn
  handler       = "bootstrap"

  source_code_hash = data.archive_file.parameter_parser.output_base64sha256

  runtime       = "provided.al2"
  architectures = ["arm64"]
}

data "aws_iam_policy_document" "parameter_parser_assume_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "parameter_parser" {
  name               = "ServiceCatalogParameterParser${random_string.random_suffix_02.result}"
  assume_role_policy = data.aws_iam_policy_document.parameter_parser_assume_policy.json
}

resource "aws_iam_role_policy" "parameter_parser" {
  name   = "ServiceCatalogParameterParserRolePolicy${random_string.random_suffix_02.result}"
  role   = aws_iam_role.parameter_parser.id
  policy = data.aws_iam_policy_document.parameter_parser.json
}

data "aws_iam_policy_document" "parameter_parser" {
  version = "2012-10-17"

  statement {
    sid = "lambdaPermissions"

    effect = "Allow"

    actions = ["sts:AssumeRole"]

    resources = ["*"]

  }

  statement {
    sid = "allowFetchingArtifactsForParsing"

    effect = "Allow"

    actions = ["s3:Get*"]

    resources = ["arn:aws:s3:::*"]

  }

}

resource "aws_iam_role_policy_attachment" "parameter_parser" {
  for_each   = toset(["arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess", "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"])
  role       = aws_iam_role.parameter_parser.name
  policy_arn = each.value
}

data "archive_file" "parameter_parser" {
  type        = "zip"
  output_path = "dist/parameter_parser.zip"
  source_file = "${path.module}/lambda-functions/terraform-parameter-parser/bootstrap"
}

resource "aws_lambda_permission" "service_catalog_parameter_parser_allowance" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.parameter_parser.function_name
  principal     = "servicecatalog.amazonaws.com"
}
