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

// arn:aws:codepipeline:us-west-1:<amazonacctId>:deployment_pipeline
// codepipeling: series of stages, and series actions w/in each stage
resource "aws_codepipeline" "deployment_pipeline" { // reference name of the resource for terraform
  // name of the actual pipeline resource in aws
  name     = "deployment-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  // <resourceType>.<referenceName>.<attribute references, ie. arn, create_date. changes by resourcetype >

  // artifact: some sort of data obj sitting in s3.
  // artifact_store: the cloud file storage system that we want to use, in this case, an s3 bucket
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  // stage: collection of actions. executes each stage in order, syncronously
  // in each pipeline, first stage must always start with a "Source" action.category
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source" // specific list
      owner            = "AWS" // specific list
      provider         = "CodeStarSourceConnection" // specific list
      version          = "1" // specific list
      output_artifacts = ["source_output"] // sets the reference to the output

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

// data is like a formatted resource "variable", does nothing by itself
// refer to: https://awspolicygen.s3.amazonaws.com/policygen.html
data "aws_iam_policy_document" "deployment_pipeline_role_policy" {
  statement {
    // statementId: optional; describing all actions inside of this statement
    // must be unique b/w all statement blocks w/in same policy
    sid = "s3 permissions"

    // allowing these actions => based on effect
    // <resourceType>:<action>
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject"
    ]

    // defaults to Allow
    effect = "Allow"

    // specifies what this set of actions applies to which ARN
    // ["*"] targets all ARNs
    resources = [
      aws_s3_bucket.codepipeline_bucket.arn
    ]
  }
}

resource "aws_iam_policy" "codepipeline_s3_policy" {
  name   = "codepipeline_s3_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.deployment_pipeline_role_policy.json // converts the data to json, policy must be stored as JSON
}

// attaches policy to the role
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_s3_policy.arn
}