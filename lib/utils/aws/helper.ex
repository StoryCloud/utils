defmodule Utils.Aws.Helper do
  def get_aws_region do
    with {:ok, %HTTPoison.Response{status_code: code, body: text}} when code in 200..299 <- HTTPoison.put("http://169.254.169.254/latest/api/token", "", [{"X-aws-ec2-metadata-token-ttl-seconds", 60}]),
         {:ok, %HTTPoison.Response{status_code: code, body: json}} when code in 200..299 <- HTTPoison.get("http://169.254.169.254/latest/dynamic/instance-identity/document", [{"X-aws-ec2-metadata-token", text}]),
         document = Jason.decode!(json) do
      document["region"]
    else
      {:ok, %HTTPoison.Response{status_code: code}} ->
        raise "Response status #{code} returned from instance metadata call"
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "Error, reason #{reason} returned from instance metadata call"
    end
  end

  def get_aws_ssm_params(region, environment, application, ssm_params_func \\ &fetch_ssm_params/3) do
    region
    |> ssm_params_func.(environment, application)
    |> parse_ssm_params(environment, application)
  end

  defp parse_ssm_params(params, environment, application) do
    Enum.reduce params, %{}, fn %{"Name" => name, "Value" => value}, memo ->
      with [^environment, ^application | keys] = String.split(name, "/", trim: true),
           item = to_map(keys, value) do
        deep_merge(memo, item)
      end
    end
  end

  defp fetch_ssm_params(region, environment, application) do
    with aws = System.find_executable("aws") do
      case System.cmd(aws, ["ssm", "get-parameters-by-path", "--region=#{region}", "--path=/#{environment}/#{application}/", "--recursive", "--with-decryption", "--query=Parameters[]"]) do
        {json, 0} ->
          Jason.decode!(json)
        {output, status} ->
          raise "SSM parameter fetch exited with status #{status}:\n#{output}"
      end
    end
  end

  defp deep_merge(a, b) do
    Map.merge(a, b, &deep_resolve/3)
  end

  defp deep_resolve(_, %{} = a, %{} = b) do
    deep_merge(a, b)
  end
  defp deep_resolve(_, _, b), do: b

  defp to_map([head | tail], value) do
    with atom = String.to_atom(head) do
      %{atom => to_map(tail, value)}
    end
  end
  defp to_map([], value), do: value
end
