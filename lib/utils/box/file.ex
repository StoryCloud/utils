defmodule Utils.Box.File do
  alias Utils.{Box.Auth}
  alias Tesla.{Middleware, Multipart}

  @box_data_endpoint "https://upload.box.com/api/2.0"
  @box_meta_endpoint "https://api.box.com/2.0"
  @file_fields "id,name,size,type"
  @small_upload_size 40_000_000

  def ensure_folder(name, parent_id) do
    with client = Auth.client([{Middleware.BaseUrl, @box_meta_endpoint}, Middleware.JSON, {Middleware.Query, [fields: @file_fields]}]),
         {:ok, %{body: body, status: 201}} <- Tesla.post(client, "folders", %{name: name, parent: %{id: parent_id}}) do
      {:ok, body}
    else
      {:ok, %{status: 409}} ->
        with {:ok, %{"type" => "folder"} = item} = get_item(name, parent_id) do
          {:ok, item}
        end
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  def ensure_file(path, name, parent_id) do
    case File.stat!(path) do
      %{size: size} when size <  @small_upload_size ->
        upload_small path, name, size, parent_id
      %{size: size} when size >= @small_upload_size ->
        upload_large path, name, size, parent_id
    end
  end

  def set_metadata(file_id, meta, scope \\ "global", template_key \\ "properties") do
    with client = Auth.client([{Middleware.BaseUrl, @box_meta_endpoint}, Middleware.JSON, Middleware.PathParams]),
         {:ok, %{body: body, status: 201}} <- Tesla.post(client, "files/:file_id/metadata/:scope/:template_key", meta, [opts: [path_params: [file_id: file_id, scope: scope, template_key: template_key]]]) do
      {:ok, body}
    else
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  defp accumulate_upload_result({:ok, item}, {:ok, items}) do
    {:ok, [item | items]}
  end

  defp build_upload_multipart(path, name, parent_id) do
    with attributes = Jason.encode!(%{name: name, parent: %{id: parent_id}}),
         multipart = Multipart.new do
      multipart
      |> Multipart.add_field("attributes", attributes)
      |> Multipart.add_file(path)
    end
  end

  defp commit_upload_session(%{"id" => session_id}, parts, sha_sum) do
    with client = Auth.client([{Middleware.BaseUrl, @box_data_endpoint}, {Middleware.Headers, [{"digest", "sha=#{sha_sum}"}]}, Middleware.JSON, Middleware.PathParams], retry_statuses: [202, 429, 500, 502, 503]),
         parts = Enum.reverse(parts),
         {:ok, %{body: body, status: 201}} <- Tesla.post(client, "files/upload_sessions/:session_id/commit", %{parts: parts}, [opts: [path_params: [session_id: session_id]]]) do
      {:ok, body}
    else
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  defp create_upload_session(name, size, parent_id) do
    with client = Auth.client([{Middleware.BaseUrl, @box_data_endpoint}, Middleware.JSON]),
         {:ok, %{body: body, status: 201}} <- Tesla.post(client, "files/upload_sessions", %{file_name: name, file_size: size, folder_id: parent_id}) do
      {:ok, body}
    else
      {:ok, %{status: 409}} ->
        with {:ok, %{"id" => file_id, "type" => "file"}} = get_item(name, parent_id),
             :ok = delete_file(file_id) do
          create_upload_session name, size, parent_id
        end
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  defp delete_file(file_id) do
    with client = Auth.client([{Middleware.BaseUrl, @box_meta_endpoint}, Middleware.JSON, Middleware.PathParams]),
         {:ok, %{status: 204}} <- Tesla.delete(client, "files/:file_id", opts: [path_params: [file_id: file_id]]) do
      :ok
    else
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  defp get_item(name, parent_id, marker \\ nil) do
    with query = [fields: @file_fields, limit: 1000, usemarker: true],
         query = if(marker, do: [{:marker, marker} | query], else: query),
         client = Auth.client([{Middleware.BaseUrl, @box_meta_endpoint}, Middleware.JSON, Middleware.PathParams, {Middleware.Query, query}]),
         {:ok, %{body: %{"entries" => entries} = body, status: 200}} <- Tesla.get(client, "folders/:parent_id/items", opts: [path_params: [parent_id: parent_id]]) do
      case Enum.find(entries, &(&1["name"] == name)) do
        nil ->
          case Map.get(body, :marker) do
            nil ->
              {:error, :not_found}
            val ->
              get_item name, parent_id, val
          end
        val ->
          {:ok, val}
      end
    else
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  defp get_sha(path) do
    with hash = :crypto.hash_init(:sha) do
      path
      |> File.stream!([], 1024*1024)
      |> Enum.reduce(hash, &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final
    end
  end

  defp settle_upload_session(session, attempts \\ 30)
  defp settle_upload_session(_, 0), do: {:error, :timeout}
  defp settle_upload_session(%{"id" => session_id} = session, attempts) when is_integer(attempts) and attempts > 0 do
    with client = Auth.client([{Middleware.BaseUrl, @box_data_endpoint}, Middleware.JSON, Middleware.PathParams]),
         {:ok, %{body: %{"num_parts_processed" => n, "total_parts" => n}, status: 200}} <- Tesla.get(client, "files/upload_sessions/:session_id", [opts: [path_params: [session_id: session_id]]]) do
      :ok
    else
      _ ->
        :timer.sleep 10_000
        settle_upload_session session, attempts - 1
    end
  end

  defp to_chunk_and_range({chunk, index}, part_size, file_size) do
    with range_start = (index + 0) * part_size,
         range_close = (index + 1) * part_size - 1,
         range_close = if(range_close >= file_size, do: file_size - 1, else: range_close) do
      {chunk, "bytes #{range_start}-#{range_close}/#{file_size}"}
    end
  end

  defp upload_chunk(%{"id" => session_id}, {chunk, range}) when is_binary(chunk) and is_binary(range) do
    with sha_sum = :crypto.hash(:sha, chunk) |> Base.encode64,
         client = Auth.client([{Middleware.BaseUrl, @box_data_endpoint}, {Middleware.Headers, [{"content-range", range}, {"content-type", "application/octet-stream"}, {"digest", "sha=#{sha_sum}"}]}, Middleware.PathParams]),
         {:ok, %{body: body, status: 200}} = Tesla.put(client, "files/upload_sessions/:session_id", chunk, opts: [path_params: [session_id: session_id]]),
         %{"part" => part} = Jason.decode!(body) do
      part
    end
  end

  defp upload_chunks(%{"part_size" => part_size} = session, path, size) do
    path
    |> File.stream!([], part_size)
    |> Stream.with_index
    |> Stream.map(&to_chunk_and_range(&1, part_size, size))
    |> Task.async_stream(&upload_chunk(session, &1), max_concurrency: 5, ordered: true, timeout: :infinity)
    |> Enum.reduce({:ok, []}, &accumulate_upload_result/2)
  end

  defp upload_large(path, name, size, parent_id) do
    with {:ok, session} <- create_upload_session(name, size, parent_id),
         {:ok, parts} <- upload_chunks(session, path, size),
         sha_sum = get_sha(path) |> Base.encode64,
         settle_upload_session(session),
         {:ok, %{"entries" => [entry]}} = commit_upload_session(session, parts, sha_sum) do
      {:ok, entry}
    end
  end

  defp upload_small(path, name, size, parent_id) do
    with sha_hex = get_sha(path) |> Base.encode16(case: :lower) do
      with client = Auth.client([{Middleware.BaseUrl, @box_data_endpoint}, {Middleware.Headers, [{"content-md5", sha_hex}]}, {Middleware.Query, [fields: @file_fields]}]),
           multipart = build_upload_multipart(path, name, parent_id),
           {:ok, %{body: body, status: 201}} <- Tesla.post(client, "files/content", multipart),
           {:ok, %{"entries" => [entry]}} = Jason.decode(body) do
        {:ok, entry}
      else
        {:ok, %{status: 409}} ->
          with {:ok, %{"id" => file_id, "type" => "file"}} = get_item(name, parent_id),
               :ok = delete_file(file_id) do
            upload_small path, name, size, parent_id
          end
        {:ok, %{status: status}} ->
          {:error, {:http_status, status}}
      end
    end
  end
end
