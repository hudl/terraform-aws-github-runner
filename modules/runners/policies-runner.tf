data "aws_caller_identity" "current" {}

resource "aws_iam_role" "runner" {
  count                = "${var.instance_role}" == null ? 1 : 0
  name                 = "${var.environment}-github-action-runners-runner-role"
  assume_role_policy   = templatefile("${path.module}/policies/instance-role-trust-policy.json", {})
  path                 = local.role_path
  permissions_boundary = var.role_permissions_boundary
  tags                 = local.tags
}

data "aws_iam_role" "custom_runner" {
  count = "${var.instance_role}" == null ? 0 : 1
  name = "${var.instance_role}"
}

resource "aws_iam_instance_profile" "runner" {
  name = "${var.environment}-github-action-runners-profile"
  role = var.instance_role == null ? aws_iam_role.runner[0].name : data.aws_iam_role.custom_runner[0].name
  path = local.instance_profile_path
}

resource "aws_iam_role_policy_attachment" "runner_session_manager_aws_managed" {
  count      = "${var.enable_ssm_on_runners}" ? 1 : 0
  role       = "${var.instance_role}" == null ? aws_iam_role.runner[0].name : data.aws_iam_role.custom_runner[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ssm_parameters" {
  name   = "runner-ssm-parameters"
  role   = "${var.instance_role}" == null ? aws_iam_role.runner[0].name : data.aws_iam_role.custom_runner[0].name
  policy = templatefile("${path.module}/policies/instance-ssm-parameters-policy.json",
    {
      arn_ssm_parameters = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}-*"
    }
  )
}

resource "aws_iam_role_policy" "dist_bucket" {
  name   = "distribution-bucket"
  role   = "${var.instance_role}" == null ? aws_iam_role.runner[0].name : data.aws_iam_role.custom_runner[0].name
  policy = templatefile("${path.module}/policies/instance-s3-policy.json",
    {
      s3_arn = var.s3_bucket_runner_binaries.arn
    }
  )
}
