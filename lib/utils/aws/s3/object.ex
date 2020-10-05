defprotocol Utils.Aws.S3.Object do
  @fallback_to_any true

  def bucket(object)
  def key(object)
  def region(object)
end

defimpl Utils.Aws.S3.Object, for: Any do
  def bucket(%{aws_s3_bucket: aws_s3_bucket}), do: aws_s3_bucket
  def bucket(%{"aws_s3_bucket" => aws_s3_bucket}), do: aws_s3_bucket

  def key(%{aws_s3_key: aws_s3_key}), do: aws_s3_key
  def key(%{"aws_s3_key" => aws_s3_key}), do: aws_s3_key

  def region(%{aws_s3_region: aws_s3_region}), do: aws_s3_region
  def region(%{"aws_s3_region" => aws_s3_region}), do: aws_s3_region
end
