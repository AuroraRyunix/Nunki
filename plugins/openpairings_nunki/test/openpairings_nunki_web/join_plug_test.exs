defmodule OpenPairingsNunkiWeb.JoinPlugTest do
  @moduledoc """
  `POST /p/nunki/join/:code` as a hall PC calls it: JSON in, JSON out, and
  the one-time code good exactly once, for fifteen minutes, in protocol
  version 1 only.
  """
  use PairingsEngineWeb.ConnCase, async: false

  import Ecto.Query
  import OpenPairingsNunki.Fixtures

  alias OpenPairingsNunki.{Announcer, Hall, JoinCode}
  alias PairingsEngine.Repo

  setup :register_and_log_in_user
  setup :setup_admin

  setup %{scope: scope} do
    t = tournament!(scope)
    {:ok, %{code: code, url: url}} = Hall.create_join_code(scope, t)
    %{t: t, code: code, url: url}
  end

  @body %{"v" => 1, "device" => "dev-abc", "name" => "Hall PC", "software" => "nunki 0.1.0"}

  defp join(code, body \\ @body) do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> post("/p/nunki/join/#{code}", Jason.encode!(body))
  end

  test "the link it is shown under ends in the join path", %{url: url, code: code} do
    assert String.ends_with?(url, "/p/nunki/join/#{code}")
    assert byte_size(code) >= 10
  end

  test "a good code joins: a key, the socket path and the tournament", %{t: t, code: code} do
    conn = join(code)
    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    body = Jason.decode!(conn.resp_body)
    assert %{"key" => key, "socket" => "/p/nunki/link", "server" => server} = body
    assert is_binary(server)
    assert body["tournament"] == %{"id" => t.id, "name" => t.name}
    assert {:ok, raw} = Base.url_decode64(key, padding: false)
    assert byte_size(raw) >= 32

    a = Repo.get_by!(Announcer, tournament_id: t.id, device_id: "dev-abc")
    assert a.name == "Hall PC"
    assert a.software == "nunki 0.1.0"
    # Only the hash is kept.
    assert a.key_hash == :crypto.hash(:sha256, key)
    assert {:ok, %Announcer{id: id}} = Hall.authenticate("dev-abc", key)
    assert id == a.id
  end

  test "a code made before the feature was switched off is expired", %{code: code, user: user} do
    {:ok, _} = PairingsEngine.Features.set_enabled(user, [])
    assert join(code).status == 410
    refute Repo.get_by(Announcer, device_id: "dev-abc")
  end

  test "a code works once", %{code: code} do
    assert join(code).status == 200
    assert join(code).status == 410
  end

  test "an expired code is refused", %{code: code} do
    Repo.update_all(JoinCode, set: [expires_at: DateTime.add(DateTime.utc_now(:second), -1)])
    conn = join(code)
    assert conn.status == 410
    assert Jason.decode!(conn.resp_body)["error"] == "expired"
  end

  test "an unknown code is a 404", %{code: code} do
    assert join("zz" <> code).status == 404
  end

  test "another protocol version is a 409, and the code is still good", %{code: code} do
    assert join(code, %{@body | "v" => 2}).status == 409
    assert join(code, Map.delete(@body, "v")).status == 409
    assert join(code).status == 200
  end

  test "a body without a device is a 400", %{code: code} do
    assert join(code, Map.delete(@body, "device")).status == 400
  end

  test "the same device joining again keeps one row, with the new key", %{
    scope: scope,
    t: t,
    code: code
  } do
    assert join(code).status == 200
    {:ok, %{code: second}} = Hall.create_join_code(scope, t)
    key = Jason.decode!(join(second).resp_body)["key"]

    assert Repo.aggregate(from(a in Announcer, where: a.tournament_id == ^t.id), :count) == 1
    assert {:ok, _} = Hall.authenticate("dev-abc", key)
  end
end
