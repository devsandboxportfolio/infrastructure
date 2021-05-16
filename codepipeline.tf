resource aws_iam_role codepipeline_role {
  name = "deployment_pipeline_role"
  path = "/service/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_codepipeline" "deployment_pipeline" {
  name     = "deployment-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        BranchName           = "master"
        ConnectionArn        = "arn:aws:codestar-connections:${var.aws_region}:${var.aws_account_id}:connection/0c85c6bd-d530-424a-8064-9b2a023b6841"
        FullRepositoryId     = "devsandboxportfolio/portfolioAPI"
        OutputArtifactFormat = "CODE_ZIP"
      }
    } 
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.example.id
      }
    }
  }
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "code-artifact-bucket-${var.aws_account_id}"
  acl    = "private"
}

data "aws_iam_policy_document" "deployment_pipeline_role_policy" {
  statement {
    sid = "1"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.codepipeline_bucket.arn
    ]
  }
}

resource "aws_iam_policy" "codepipeline_s3_policy" {
  name   = "codepipeline_s3_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.deployment_pipeline_role_policy.json
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_s3_policy.arn
}