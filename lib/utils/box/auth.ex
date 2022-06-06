defmodule Utils.Box.Auth do
  use GenServer
  alias Tesla.Middleware

  defstruct [:access_token, :client, :config, :expires_at, :refresh_token]

  @auth_token_buffer [seconds: 600]
  @box_auth_base "https://api.box.com"
  @box_auth_path "/oauth2/token"

  @auth_client_middlewares [
    {Middleware.BaseUrl, @box_auth_base},
    Middleware.FormUrlencoded,
    Middleware.Logger,
    Middleware.Retry,
  ]

  def client(middlewares) do
    GenServer.call(__MODULE__, {:client, middlewares})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    with client = Tesla.client(@auth_client_middlewares) do
      case opts do
        #
        # Copied tokens for development
        #
        [access_token: access_token, expires: expires] ->
          with expires_at = Timex.parse!(expires, "{Mfull} {D}, {YYYY} at {h12}:{m}:{s} {AM}"),
               expires_at = Timex.to_datetime(expires_at, "America/New_York") do
            {:ok, %__MODULE__{access_token: access_token, client: client, expires_at: expires_at}}
          end
        #
        # Configuration for production
        #
        config when is_list(config) ->
          {:ok, %__MODULE__{client: client, config: config}}
      end
    end
  end

  @impl GenServer
  def handle_call({:client, middlewares}, _, %__MODULE__{} = status) do
    with %{access_token: access_token} = status = maybe_update_status(status),
         client = build_authorized_client(access_token, middlewares) do
      {:reply, client, status}
    end
  end

  defp build_authorized_client(access_token, middlewares) do
    with middlewares = [{Middleware.BearerAuth, [token: access_token]}, Middleware.Logger, {Middleware.Retry, should_retry: &should_retry?/1} | middlewares] do
      Tesla.client middlewares
    end
  end

  defp build_jwt(config) do
    with aud = Path.join(@box_auth_base, @box_auth_path),
         kid = Keyword.fetch!(config, :public_key_id),
         iss = Keyword.fetch!(config, :client_id),
         pem = Keyword.fetch!(config, :private_key),
         sub = Keyword.fetch!(config, :enterprise_id),
         config = Joken.Config.default_claims(default_exp: 45, skip: [:iss, :aud]),
         signer = Joken.Signer.create("RS512", %{"pem" => pem}, %{"kid" => kid}) do
      Joken.generate_and_sign! config, %{"aud" => aud, "box_sub_type" => "enterprise", "iss" => iss, "sub" => sub}, signer
    end
  end

  defp login(client, config) do
    with claims = build_jwt(config),
         {:ok, body} <- post(client, config, %{assertion: claims, grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer"}),
         auth = parse_auth(body) do
      {:ok, auth}
    end
  end

  defp maybe_update_status(%__MODULE__{access_token: access_token, client: client, config: config, expires_at: expires_at, refresh_token: refresh_token} = status) do
    with time_now = Timex.now,
         time_buf = Timex.shift(time_now, @auth_token_buffer) do
      cond do
        not is_nil(access_token) and Timex.before?(time_buf, expires_at) ->
          status

        not is_nil(refresh_token) and Timex.before?(time_now, expires_at) ->
          with {:ok, %{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token}} = renew(client, config, refresh_token) do
            %{status | access_token: access_token, expires_at: expires_at, refresh_token: refresh_token}
          end

        true ->
          with {:ok, %{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token}} = login(client, config) do
            %{status | access_token: access_token, expires_at: expires_at, refresh_token: refresh_token}
          end
      end
    end
  end

  defp parse_auth(%{"access_token" => access_token, "expires_in" => expires_in} = body) when is_integer(expires_in) do
    with time_now = Timex.now,
         expires_at = Timex.shift(time_now, seconds: expires_in - 5),
         refresh_token = Map.get(body, "refresh_token") do
      %{access_token: access_token, expires_at: expires_at, refresh_token: refresh_token}
    end
  end

  defp post(client, config, params) do
    with client_id = Keyword.fetch!(config, :client_id),
         client_secret = Keyword.fetch!(config, :client_secret),
         params = Map.merge(params, %{client_id: client_id, client_secret: client_secret}),
         {:ok, %{body: body, status: 200}} <- Tesla.post(client, @box_auth_path, params) do
      Jason.decode body
    else
      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}
    end
  end

  defp renew(client, config, refresh_token) do
    with {:ok, body} <- post(client, config, %{grant_type: "refresh_token", refresh_token: refresh_token}),
         auth = parse_auth(body) do
      {:ok, auth}
    end
  end

  defp should_retry?({:ok, 500}), do: true
  defp should_retry?({:ok, _}), do: false
  defp should_retry?({:error, _}), do: true
end
