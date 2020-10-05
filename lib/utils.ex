defmodule Utils do
  alias Utils.{Aws, Rel}

  defdelegate get_aws_region, to: Aws.Helper

  defdelegate get_aws_s3_signature(canonical_request, params), to: Aws.S3.Signature

  defdelegate get_aws_s3_signed_url(object, opts), to: Aws.S3

  defdelegate get_aws_ssm_params(region, environment, application), to: Aws.Helper
  defdelegate get_aws_ssm_params(region, environment, application, ssm_params_func), to: Aws.Helper

  defdelegate migrate(app), to: Rel.Task

  defdelegate valid_aws_s3_upload_request?(canonical_request, date_time, config), to: Aws.S3.Signature
end
