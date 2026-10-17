defmodule NunkiWeb.LauncherStatsTest do
  @moduledoc """
  `GET /_launcher/stats` (`NunkiWeb.Plugs.LauncherStats`): a loopback
  peer, this start's secret and no proxy header, or a 404.
  """
  use Nunki.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint NunkiWeb.Endpoint

  @token "a-launcher-secret-for-this-test"

  setup do
    Application.put_env(:nunki, :launcher_token, @token)
    on_exit(fn -> Application.delete_env(:nunki, :launcher_token) end)
    %{conn: build_conn()}
  end

  defp ask(conn, token) do
    conn = if token, do: put_req_header(conn, "x-launcher-token", token), else: conn
    get(conn, "/_launcher/stats")
  end

  test "no secret, a wrong one, or an empty one: 404", %{conn: conn} do
    assert ask(conn, nil).status == 404
    assert ask(build_conn(), "not-the-secret").status == 404
    assert ask(build_conn(), "").status == 404
  end

  test "the secret from another machine: 404", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.put_peer_data(%{address: {192, 168, 1, 23}, port: 50_000, ssl_cert: nil})
      |> ask(@token)

    assert conn.status == 404
  end

  test "a forwarded header does not make a request local", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.put_peer_data(%{address: {10, 0, 0, 7}, port: 50_000, ssl_cert: nil})
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> ask(@token)

    assert conn.status == 404
  end

  test "a proxy header on a loopback request: 404" do
    for header <- ~w(x-forwarded-for forwarded x-real-ip cf-connecting-ip x-forwarded-host) do
      conn = build_conn() |> put_req_header(header, "203.0.113.9") |> ask(@token)
      assert conn.status == 404, header
    end
  end

  test "no secret made (details switched off): 404 even with a guess", %{conn: conn} do
    Application.delete_env(:nunki, :launcher_token)
    assert ask(conn, @token).status == 404
  end

  test "anything but GET: 404", %{conn: conn} do
    conn = conn |> put_req_header("x-launcher-token", @token) |> post("/_launcher/stats", %{})
    assert conn.status == 404
  end

  test "with the secret: the documented shape, and no key in it", %{conn: conn} do
    {:ok, _} =
      Nunki.Store.add_tournament(%{
        "server" => "fake",
        "socket" => "ws://127.0.0.1:1/p/nunki/link",
        "key" => "the-tournament-key",
        "tournament" => %{"id" => "t-1", "name" => "Fake Open"}
      })

    conn = ask(conn, @token)
    assert conn.status == 200
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    refute conn.resp_body =~ @token
    refute conn.resp_body =~ "the-tournament-key"

    assert %{
             "app" => "nunki",
             "version" => _,
             "uptime_s" => _,
             "system" => %{"os" => _, "arch" => _},
             "beam" => %{"memory_bytes" => %{"total" => _}, "schedulers" => _},
             "state" => %{"path" => path, "size_bytes" => size},
             "log" => %{"source" => _},
             "nunki" => %{
               "live_views" => _,
               "tournaments" => 1,
               "links_up" => 0,
               "voice" => voice,
               "speaking" => false
             },
             "summary" => [_ | _] = summary
           } = Jason.decode!(conn.resp_body)

    assert String.ends_with?(path, "state.json")
    assert is_integer(size)
    assert voice =~ "Fake English"
    assert Enum.map(summary, & &1["label"]) == Nunki.LauncherDetails.Stats.labels("en")
  end

  test "in Dutch when asked", %{conn: conn} do
    conn = conn |> put_req_header("x-launcher-token", @token) |> get("/_launcher/stats?lang=nl")
    labels = conn.resp_body |> Jason.decode!() |> Map.fetch!("summary") |> Enum.map(& &1["label"])
    assert labels == Nunki.LauncherDetails.Stats.labels("nl")
    assert "Stem" in labels
  end
end
