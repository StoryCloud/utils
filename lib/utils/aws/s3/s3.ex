defmodule Utils.Aws.S3 do
  alias Utils.Aws.S3.{Object, Signature}

  def get_aws_s3_signed_url(object, opts) do
    with bucket = Object.bucket(object),
         key = Object.key(object),
         aws_region = Object.region(object),
         host = "s3.#{aws_region}.amazonaws.com",
         path = "/#{bucket}/#{key}",
         params = signature_params(aws_region, host, path, opts),
         signed_query = Signature.signed_query(params) do
      "https://#{host}#{path}?#{signed_query}"
    end
  end

  defp add_signature_times(params, opts) do
    with start = Timex.now |> Timex.shift(minutes: -5),
         shift = opts[:timeout] || [hours: 1],
         close = Timex.shift(start, shift) do
      params
      |> Map.put(:date_time, start)
      |> Map.put(:expires_seconds, Timex.Interval.new(from: start, to: close) |> Timex.Interval.duration(:seconds))
    end
  end

  defp maybe_add_cache_control(query, opts) do
    unless opts[:cache] do
      Map.put(query, "response-cache-control", "no-cache, no-store, max-age=0, must-revalidate")
    end
  end

  defp maybe_add_content_disposition(query, opts) do
    case opts[:file_name] do
      nil -> query
      val -> Map.put(query, "response-content-disposition", "attachment; filename=\"#{val}\"")
    end
  end

  defp maybe_add_content_type(query, opts) do
    case opts[:mime_type] do
      nil -> query
      val -> Map.put(query, "response-content-type", val)
    end
  end

  defp maybe_add_signature_custom_query(params, opts) do
    %{}
    |> maybe_add_cache_control(opts)
    |> maybe_add_content_disposition(opts)
    |> maybe_add_content_type(opts)
    |> (&(if Enum.empty?(&1), do: params, else: Map.put(params, :custom_query, &1))).()
  end

  defp signature_params(aws_region, host, path, opts) do
    %{
      aws_access_key: opts[:access_key],
      aws_region: aws_region,
      aws_secret_key: opts[:secret_key],
      host: host,
      path: path,
      verb: "GET"
    }
    |> add_signature_times(opts)
    |> maybe_add_signature_custom_query(opts)
  end
end
