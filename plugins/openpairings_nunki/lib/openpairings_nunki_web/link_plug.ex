defmodule OpenPairingsNunkiWeb.LinkPlug do
  @moduledoc """
  `GET /p/nunki/link`: upgrades the request to the announcer's WebSocket
  (`OpenPairingsNunkiWeb.LinkSocket`). Who is calling is settled inside,
  by the `hello` frame - the key never travels in a URL, which proxies
  write down. A request that is not a WebSocket upgrade gets a 426 and a
  short explanation.
  """
  @behaviour Plug

  import Plug.Conn

  # Longer than the announcers' 25-second ping, so an idle link with a
  # living device on the other end is never cut by the server.
  @idle_timeout 90_000

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> WebSockAdapter.upgrade(OpenPairingsNunkiWeb.LinkSocket, %{}, timeout: @idle_timeout)
    |> halt()
  rescue
    WebSockAdapter.UpgradeError ->
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(426, "This is the Nunki hall link; it speaks WebSocket only.\n")
      |> halt()
  end
end
