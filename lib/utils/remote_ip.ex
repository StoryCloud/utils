defmodule Utils.RemoteIp do
  def get(conn) do
    with forwarded_for = get_forwarded_for(conn) do
      if forwarded_for do
        forwarded_for
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> List.first()
      else
        conn.remote_ip
        |> :inet_parse.ntoa()
        |> to_string()
      end
    end
  end

  defp get_forwarded_for(conn) do
    conn
    |> Plug.Conn.get_req_header("x-forwarded-for")
    |> List.first()
  end
end
