# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#Create a random resource`s name 
resource "random_string" "random_suffix_01" {
  length  = 5
  special = false
  upper   = true
}

data "archive_file" "provision_handler" {
  type        = "zip"
  output_path = "dist/provisioning_operations_handler.zip"
  source_file = "${path.module}/lambda-functions/provisioning-operations-handler/bootstrap"
}

# Lambda for provisioning products

data "aws_iam_policy_document" "provision_handler" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "provisioning_handler_lambda_execution" {
  name               = "ServiceCatalogProvisionHandlerRole-${random_string.random_suffix_01.result}"
  assume_role_policy = data.aws_iam_policy_document.provision_handler.json
}

resource "aws_iam_role_policy" "provision_handler_lambda_execution_role_policy" {
  name   = "ServiceCatalogProvisionHandler${random_string.random_suffix_01.result}Policy"
  role   = aws_iam_role.provisioning_handler_lambda_execution.id
  policy = data.aws_iam_policy_document.policy_for_provision_handler.json
}

data "aws_iam_policy_document" "policy_for_provision_handler" {
  version = "2012-10-17"

  statement {
    sid = "AllowSqs"

    effect = "Allow"

    actions = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]

    resources = [aws_sqs_queue.terraform_engine_provision_operation_queue.arn]

  }

  statement {
    sid = "AllowKmsDecrypt"

    effect = "Allow"

    actions = ["kms:Decrypt"]

    resources = [aws_kms_key.queue_key.arn]

  }

  statement {
    sid = "AllowStepFunction"

    effect = "Allow"

    actions = ["states:StartExecution"]

    resources = [aws_sfn_state_machine.provision_state_machine.arn]

  }
}

resource "aws_iam_role_policy_attachment" "provision_handler_lambda_execution" {
  for_each   = toset(["arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess", "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"])
  role       = aws_iam_role.provisioning_handler_lambda_execution.name
  policy_arn = each.value
}

resource "aws_lambda_function" "provision_handler" {
  function_name = "ServiceCatalogProvisionHandlerLambda"
  role          = aws_iam_role.provisioning_handler_lambda_execution.arn
  handler       = "bootstrap"

  filename         = data.archive_file.provision_handler.output_path
  source_code_hash = data.archive_file.provision_handler.output_base64sha256

  runtime       = "provided.al2"
  architectures = ["arm64"]

  environment {
    variables = {
      TERRAFORM_ORGANIZATION = var.tfc_organization
      STATE_MACHINE_ARN      = aws_sfn_state_machine.provision_state_machine.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "provision_handler_provision_queue" {
  event_source_arn        = aws_sqs_queue.terraform_engine_provision_operation_queue.arn
  function_name           = aws_lambda_function.provision_handler.arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

# Lambda for terminating products

data "aws_iam_policy_document" "terminate_handler" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "terminate_handler_lambda_execution" {
  name               = "ServiceCatalogTerminateHandlerRole${random_string.random_suffix_01.result}"
  assume_role_policy = data.aws_iam_policy_document.terminate_handler.json
}

resource "aws_iam_role_policy" "terminate_handler_lambda_execution_role_policy" {
  name   = "ServiceCatalogTerminateHandler${random_string.random_suffix_01.result}Policy"
  role   = aws_iam_role.terminate_handler_lambda_execution.id
  policy = data.aws_iam_policy_document.policy_for_terminate_handler.json
}

data "aws_iam_policy_document" "policy_for_terminate_handler" {
  version = "2012-10-17"

  statement {
    sid = "AllowSqs"

    effect = "Allow"

    actions = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]

    resources = [aws_sqs_queue.terraform_engine_terminate_queue.arn]

  }

  statement {
    sid = "AllowKmsDecrypt"

    effect = "Allow"

    actions = ["kms:Decrypt"]

    resources = [aws_kms_key.queue_key.arn]

  }

  statement {
    sid = "AllowStepFunction"

    effect = "Allow"

    actions = ["states:StartExecution"]

    resources = [aws_sfn_state_machine.terminate_state_machine.arn]

  }
}

resource "aws_lambda_function" "terminate_handler" {
  function_name = "ServiceCatalogTerminateHandlerLambda"
  role          = aws_iam_role.terminate_handler_lambda_execution.arn
  handler       = "bootstrap"

  filename         = data.archive_file.provision_handler.output_path
  source_code_hash = data.archive_file.provision_handler.output_base64sha256

  runtime       = "provided.al2"
  architectures = ["arm64"]

  environment {
    variables = {
      TERRAFORM_ORGANIZATION = var.tfc_organization
      STATE_MACHINE_ARN      = aws_sfn_state_machine.terminate_state_machine.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "terminate_handler_terminate_queue" {
  event_source_arn        = aws_sqs_queue.terraform_engine_terminate_queue.arn
  function_name           = aws_lambda_function.terminate_handler.arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

# Lambda for updating products

data "aws_iam_policy_document" "update_handler" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "update_handler_lambda_execution" {
  name               = "ServiceCatalogUpdateHandlerRole-${random_string.random_suffix_01.result}"
  assume_role_policy = data.aws_iam_policy_document.update_handler.json
}

resource "aws_iam_role_policy" "update_handler_lambda_execution_role_policy" {
  name   = "ServiceCatalogUpdateHandler${random_string.random_suffix_01.result}Policy"
  role   = aws_iam_role.update_handler_lambda_execution.id
  policy = data.aws_iam_policy_document.policy_for_update_handler.json
}

data "aws_iam_policy_document" "policy_for_update_handler" {
  version = "2012-10-17"

  statement {
    sid = "AllowSqs"

    effect = "Allow"

    actions = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]

    resources = [aws_sqs_queue.terraform_engine_update_queue.arn]

  }

  statement {
    sid = "AllowKmsDecrypt"

    effect = "Allow"

    actions = ["kms:Decrypt"]

    resources = [aws_kms_key.queue_key.arn]

  }

  statement {
    sid = "AllowStepFunction"

    effect = "Allow"

    actions = ["states:StartExecution"]

    resources = [aws_sfn_state_machine.update_state_machine.arn]

  }
}

resource "aws_lambda_function" "update_handler" {
  function_name = "ServiceCatalogUpdateHandlerLambda"
  role          = aws_iam_role.update_handler_lambda_execution.arn
  handler       = "bootstrap"

  filename         = data.archive_file.provision_handler.output_path
  source_code_hash = data.archive_file.provision_handler.output_base64sha256

  runtime       = "provided.al2"
  architectures = ["arm64"]

  environment {
    variables = {
      TERRAFORM_ORGANIZATION = var.tfc_organization
      STATE_MACHINE_ARN      = aws_sfn_state_machine.update_state_machine.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "update_handler_update_queue" {
  event_source_arn        = aws_sqs_queue.terraform_engine_update_queue.arn
  function_name           = aws_lambda_function.update_handler.arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}
