defmodule OpenPairingsNunki.RoundPayloadTest do
  @moduledoc """
  The round payload: boards as the printed pairing list has them, the bye,
  the name to say aloud, the owner's language, and a `rev` that is the
  payload's own hash.
  """
  use PairingsEngineWeb.ConnCase, async: false

  import OpenPairingsNunki.Fixtures

  alias OpenPairingsNunki.RoundPayload
  alias PairingsEngine.Repo

  setup :register_and_log_in_user
  setup :setup_admin

  setup %{scope: scope} do
    %{t: tournament!(scope)}
  end

  test "nothing before a round is published", %{t: t} do
    assert RoundPayload.latest(t) == nil
  end

  test "the published round, its boards and its bye", %{t: t} do
    publish!(t, 1)
    p = RoundPayload.latest(t.id)

    assert p["round"] == 1
    assert p["rounds"] == 5
    assert p["team"] == false
    assert p["rating_label"] == "Elo"
    assert p["locale"] == "en"
    assert is_binary(p["published_at"])

    assert p["tournament"] == %{
             "id" => t.id,
             "name" => "Open of Somewhere",
             "city" => "Somewhere",
             "dates" => "2026-10-18 - 2026-10-20"
           }

    # Five players: two games and a bye, the bye last.
    assert [b1, b2, bye] = p["boards"]
    assert b1["board"] == "1"
    assert b2["board"] == "2"
    assert b1["bye"] == nil and is_map(b1["black"])
    assert bye["black"] == nil
    assert bye["bye"] == "bye"

    players =
      Enum.flat_map(p["boards"], &Enum.reject([&1["white"], &1["black"]], fn x -> is_nil(x) end))

    anna = Enum.find(players, &(&1["name"] == "Alpha, Anna"))
    assert anna["spoken"] == "Anna Alpha"
    assert anna["title"] == "GM"
    assert anna["rating"] == 2400
    assert anna["federation"] == "BEL"
    assert anna["score"] == "0"
    assert is_integer(anna["number"])
    assert Enum.find(players, &(&1["name"] == "Charlie"))["spoken"] == "Charlie"

    assert p["rev"] == RoundPayload.rev(p)
    assert p["rev"] =~ ~r/\A[0-9a-f]{64}\z/
  end

  test "the owner's language decides the locale", %{t: t, user: user} do
    user |> Ecto.Changeset.change(locale: "nl") |> Repo.update!()
    publish!(t, 1)
    assert RoundPayload.latest(t)["locale"] == "nl"
  end

  test "spoken names" do
    assert RoundPayload.spoken("Carlsen, Magnus") == "Magnus Carlsen"
    assert RoundPayload.spoken("Carlsen,Magnus") == "Magnus Carlsen"
    assert RoundPayload.spoken("Magnus Carlsen") == "Magnus Carlsen"
    assert RoundPayload.spoken("Carlsen,") == "Carlsen"
  end

  test "for_room cuts to the room's boards, names it and moves the rev", %{t: t} do
    publish!(t, 1)
    p = RoundPayload.latest(t.id)
    room = %{name: "Annex", ranges: [{2, 2}]}

    assert RoundPayload.for_room(p, nil) == p
    assert RoundPayload.for_room(nil, room) == nil

    cut = RoundPayload.for_room(p, room)
    assert Enum.map(cut["boards"], & &1["board"]) == ["2"]
    assert cut["room"] == "Annex"
    assert cut["rev"] != p["rev"]
    assert cut["rev"] == RoundPayload.rev(cut)

    # A room holding nothing holds no boards.
    assert RoundPayload.for_room(p, %{name: "Empty", ranges: []})["boards"] == []
  end
end
