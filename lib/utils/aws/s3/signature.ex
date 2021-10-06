defmodule Utils.Aws.S3.Signature do
  def get_aws_s3_signature(canonical_request, params) do
    canonical_request
    |> string_to_sign(params)
    |> signed_string(params)
  end

  def signed_query(params) do
    "#{canonical_query params}&X-Amz-Signature=#{signature params}"
  end

  def valid_aws_s3_upload_request?(canonical_request, date_time, config) do
    canonical_request
    |> String.split("\n")
    |> valid_request?(["PUT", "POST"], date_time, config)
  end

  defp canonical_query(%{aws_access_key: aws_access_key, expires_seconds: expires_seconds} = params) do
    with credential = "#{aws_access_key}/#{scope(params)}" do
      params
      |> Map.get(:custom_query, %{})
      |> Map.merge(%{
        "X-Amz-Algorithm" => "AWS4-HMAC-SHA256",
        "X-Amz-Credential" => credential,
        "X-Amz-Date" => iso8601_date_time(params),
        "X-Amz-Expires" => "#{expires_seconds}",
        "X-Amz-SignedHeaders" => "host"
      })
      |> Enum.into([])
      |> List.keysort(0)
      |> Enum.map(fn {key, val} -> "#{uri_encode key}=#{uri_encode val}" end)
      |> Enum.join("&")
    end
  end

  defp canonical_request(%{verb: verb, path: path, host: host} = params) do
    "#{verb}\n#{uri_encode(path, unescape_slash: true)}\n#{canonical_query(params)}\nhost:#{String.trim(host)}\n\nhost\nUNSIGNED-PAYLOAD"
  end
  #
  # Amazon has specific requirements for URI-encoding the values used in signatures.
  #
  defp char_unescaped?(char, unescape_slash?) do
    char in ?0..?9 or char in ?a..?z or char in ?A..?Z or char in '~_-.' or (char == ?/ and unescape_slash?)
  end

  defp hmac_sha256(a, b) do
    :crypto.mac(:hmac, :sha256, a, b)
  end

  defp iso8601_date_time(%{date_time: date_time}) do
    utc_date_time_with_format(date_time, "%Y%m%dT%H%M%SZ")
  end

  defp parse_canonical_request_headers(headers) do
    headers
    |> Enum.join("\n")
    |> String.split("\n", trim: true)
    |> Enum.map(&String.split(&1, ":"))
    |> Enum.map(&List.to_tuple/1)
    |> Enum.into(%{})
  end

  defp scope(%{aws_region: aws_region} = params) do
    "#{utc_date params}/#{aws_region}/s3/aws4_request"
  end

  defp sha_hex(canonical_request) do
    canonical_request
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16
    |> String.downcase
  end

  defp signature(params) do
    params
    |> canonical_request()
    |> get_aws_s3_signature(params)
  end

  defp signed_string(string_to_sign, params) do
    params
    |> signing_key()
    |> hmac_sha256(string_to_sign)
    |> Base.encode16
    |> String.downcase
  end

  defp signing_key(%{aws_secret_key: aws_secret_key, aws_region: aws_region} = params) do
    "AWS4#{aws_secret_key}"
    |> hmac_sha256(utc_date(params))
    |> hmac_sha256(aws_region)
    |> hmac_sha256("s3")
    |> hmac_sha256("aws4_request")
  end

  defp string_to_sign(canonical_request, params) do
    Enum.join([
      "AWS4-HMAC-SHA256",
      iso8601_date_time(params),
      scope(params),
      sha_hex(canonical_request)
    ], "\n")
  end

  defp uri_encode(binary, opts \\ []) do
    URI.encode binary, &char_unescaped?(&1, !!opts[:unescape_slash])
  end

  defp utc_date(%{date_time: date_time}) do
    utc_date_time_with_format(date_time, "%Y%m%d")
  end

  defp utc_date_time_with_format(date_time, format) do
    with utc_timezone = Timex.Timezone.get("UTC", date_time) do
      date_time
      |> Timex.Timezone.convert(utc_timezone)
      |> Timex.format!(format, :strftime)
    end
  end

  defp valid_request?([verb, path, _ | rest], verbs, date_time, config) do
    with [_, _ | headers] <- Enum.reverse(rest),
         %{"host" => headers_host, "x-amz-date" => x_amz_date} <- parse_canonical_request_headers(headers),
         %{host: config_url_host} <- URI.parse(config[:aws_url]),
         iso8601_date = iso8601_date_time(%{date_time: date_time}),
         prefix = "/#{config[:s3_bucket]}/#{config[:s3_prefix]}",
         uri_encoded_prefix = uri_encode(prefix, unescape_slash: true) do
      verb in verbs and headers_host == config_url_host and x_amz_date == iso8601_date and String.starts_with?(path, uri_encoded_prefix)
    else
      _ -> false
    end
  end
  defp valid_request?(_, _, _, _), do: false
end
