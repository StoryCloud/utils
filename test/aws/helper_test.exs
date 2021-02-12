defmodule Aws.HelperTest do
  use ExUnit.Case
  doctest Utils

  describe "get_aws_ssm_params/4" do
    test "Should parse the parameters into nested maps" do
      Utils.get_aws_ssm_params("us-west-2", "test", "depos", &ssm_params/3)
      |> case do params ->
             assert params.aws.s3.primary_bucket.name == "storycloud-test-video-store"
         end
    end
  end

  defp ssm_params(_, environment, application) do
    ~s"""
    [
      {
        "Name": "/#{environment}/#{application}/aws/cognito/developer_provider_name",
        "Type": "String",
        "Value": "com.storycloud.#{environment}-depo-devices",
        "Version": 1,
        "LastModifiedDate": 1578441864.005,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/aws/cognito/developer_provider_name"
      },
      {
        "Name": "/#{environment}/#{application}/aws/cognito/identity_pool",
        "Type": "String",
        "Value": "us-west-2:251d437d-f620-4423-acc9-cb0056f195cf",
        "Version": 1,
        "LastModifiedDate": 1578441863.56,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/aws/cognito/identity_pool"
      },
      {
        "Name": "/#{environment}/#{application}/aws/rds/endpoint_name",
        "Type": "String",
        "Value": "#{environment}-rds.ctpioeu25oil.us-west-2.rds.amazonaws.com",
        "Version": 1,
        "LastModifiedDate": 1578441864.295,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/aws/rds/endpoint_name"
      },
      {
        "Name": "/#{environment}/#{application}/aws/rds/endpoint_port",
        "Type": "String",
        "Value": "5432",
        "Version": 1,
        "LastModifiedDate": 1578507864.01,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/aws/rds/endpoint_port"
      },
      {
        "Name": "/#{environment}/#{application}/aws/s3/primary_bucket/name",
        "Type": "String",
        "Value": "storycloud-#{environment}-video-store",
        "Version": 1,
        "LastModifiedDate": 1579205931.39,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/aws/s3/primary_bucket/name"
      },
      {
        "Name": "/#{environment}/#{application}/aws/s3/primary_bucket/read_access_role_arn",
        "Type": "String",
        "Value": "arn:aws:iam::137378391578:role/#{environment}-#{application}-PrimaryS3BucketReadAccessRole-19BCLIHDF4SFO",
        "Version": 1,
        "LastModifiedDate": 1579205953.141,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/aws/s3/primary_bucket/read_access_role_arn"
      },
      {
        "Name": "/#{environment}/#{application}/https_forwarding/port",
        "Type": "String",
        "Value": "81",
        "Version": 1,
        "LastModifiedDate": 1578507863.442,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/https_forwarding/port"
      },
      {
        "Name": "/#{environment}/#{application}/media_conversion/host",
        "Type": "String",
        "Value": "internal-#{environment}-media-elb-381454456.us-west-2.elb.amazonaws.com",
        "Version": 1,
        "LastModifiedDate": 1578441864.007,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/media_conversion/host"
      },
      {
        "Name": "/#{environment}/#{application}/media_conversion/port",
        "Type": "String",
        "Value": "8080",
        "Version": 1,
        "LastModifiedDate": 1578441864.397,
        "ARN": "arn:aws:ssm:us-west-2:137378391578:parameter/#{environment}/#{application}/media_conversion/port"
      }
    ]
    """
    |> Jason.decode!
  end
end
