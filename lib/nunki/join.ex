defmodule Nunki.Join do
  @moduledoc """
  Joining a tournament: the whole of it is one link.

  OpenPairings' "Add an announcer" (on the tournament's Hall announcer
  page) shows `https://<server>/p/nunki/join/<code>`, as text and as a QR
  code, good for fifteen minutes and for one device. The operator pastes it
  into the control page and presses Join; Nunki POSTs to that very address
  who it is, and the answer is its own long key, where the link's socket
  is, what the server is called and which tournament this is. The key goes
  into `state.json` and is never shown.

  Anything before `/p/` is kept as it is, so OpenPairings behind a sub-path
  (`https://example.org/chess/p/nunki/join/...`) works. A print station's
  link (`/p/polis/join/...`) is refused before anything is sent: the code
  would be spent on the wrong device.

  Answers (docs/protocol.md): 200 with `key`, `socket`, `server`,
  `tournament`; 404 or 410 a code that is unknown, used or expired; 409 a
  protocol version the server does not speak; anything else is not an
  OpenPairings server.
  """

  @version 1
  @product "nunki"

  def version, do: @version

  @doc """
  `{:ok, %{"server", "socket", "key", "tournament"}}` - what
  `Nunki.Store.add_tournament/1` takes - or `{:error, reason}` with
  `reason` one of `:not_a_link`, `{:other_product, name}`,
  `:used_or_expired`, `:version`, `:not_a_server`, `:unreachable`.
  """
  def redeem(link, identity, req_options \\ []) do
    with {:ok, uri} <- parse(link) do
      url = URI.to_string(%{uri | query: nil, fragment: nil})

      options =
        Keyword.merge(
          [
            json: identity,
            retry: false,
            receive_timeout: 15_000,
            connect_options: [timeout: 10_000]
          ],
          req_options
        )

      case Req.post(url, options) do
        {:ok,
         %{
           status: 200,
           body: %{"key" => key, "socket" => "/" <> _ = socket, "tournament" => %{"id" => _} = t}
         } = response}
        when is_binary(key) and key != "" ->
          {:ok,
           %{
             "server" => response.body["server"] || uri.host,
             "socket" => socket_url(uri, socket),
             "key" => key,
             "tournament" => %{"id" => t["id"], "name" => t["name"] || ""}
           }}

        {:ok, %{status: status}} when status in [404, 410] ->
          {:error, :used_or_expired}

        {:ok, %{status: 409}} ->
          {:error, :version}

        {:ok, _other} ->
          {:error, :not_a_server}

        {:error, _exception} ->
          {:error, :unreachable}
      end
    end
  end

  @doc """
  The join link's parts: `{:ok, uri}`, `{:error, {:other_product, name}}`
  for another hall program's link, or `{:error, :not_a_link}`.
  """
  def parse(link) when is_binary(link) do
    with {:ok, %URI{scheme: scheme, host: host, path: path} = uri}
         when scheme in ["http", "https"] and is_binary(host) and host != "" and is_binary(path) <-
           URI.new(String.trim(link)),
         [_before, rest] <- split_last(path),
         [product, "join", code] when code != "" <- String.split(rest, "/") do
      if product == @product, do: {:ok, uri}, else: {:error, {:other_product, product}}
    else
      _other -> {:error, :not_a_link}
    end
  end

  def parse(_other), do: {:error, :not_a_link}

  # The LAST "/p/" in the path: a sub-path may itself contain one.
  defp split_last(path) do
    case :binary.matches(path, "/p/") do
      [] ->
        :none

      matches ->
        {at, len} = List.last(matches)
        [binary_part(path, 0, at), binary_part(path, at + len, byte_size(path) - at - len)]
    end
  end

  # Where the socket is: the same host and port, ws for http, wss for https.
  defp socket_url(uri, path) do
    scheme = if uri.scheme == "https", do: "wss", else: "ws"
    URI.to_string(%URI{scheme: scheme, host: uri.host, port: uri.port, path: path})
  end
end
