defmodule OpenPairingsNunki.RoundPayload do
  @moduledoc """
  The round payload an announcer gets in a `round` frame: the latest
  published round's pairings, in the shape both hall plugins (Nunki and
  Polis) send, byte for byte the same JSON.

  Boards, their order and the scores are the core's printed pairing list's
  (`PairingsEngineWeb.PrintController.pairing_list/2`): hidden pairings
  out, `PairingsEngine.PairingDisplay.with_display_boards/1` for board
  labels and order, scores coming INTO the round from
  `PairingsEngine.Standings.player_scores_before_round/2`, the rating the
  tournament's own rating method picks (`Player.rating/2`). Team
  tournaments send their board pairings as the core lists them, which is a
  limit rather than a feature.

  `rev` is the SHA-256 of the payload without it, over a canonical
  encoding (keys sorted), so it changes exactly when something an
  announcer would read changed.
  """
  alias PairingsEngine.{PairingDisplay, Repo, Standings, Tournaments}
  alias PairingsEngine.Tournaments.{Player, Tournament}

  @doc """
  The payload of the latest published round of tournament `id` (an id or a
  `%Tournament{}`), or nil when no round is public yet or the tournament
  is gone.
  """
  def latest(%Tournament{id: id}), do: latest(id)

  def latest(tournament_id) do
    with %Tournament{} = t <- Tournaments.get_tournament(tournament_id),
         n when n > 0 <- Tournaments.latest_published_round_number(t),
         round when not is_nil(round) <- Tournaments.get_round(t.id, n),
         true <- Tournaments.round_published?(t, round) do
      build(Repo.preload(t, :user), round)
    else
      _ -> nil
    end
  end

  @doc "The payload for `round` of `tournament` (its `user` preloaded), published or not."
  def build(%Tournament{} = t, round) do
    scores = Standings.player_scores_before_round(t, round.number)
    locale = locale(t)

    boards =
      round.pairings
      |> Enum.reject(& &1.hidden)
      |> PairingDisplay.with_display_boards()
      |> Enum.map(fn %{pairing: p, board: board} ->
        %{
          "board" => to_string(board),
          "white" => player(p.white_player, t, scores),
          "black" => player(p.black_player, t, scores),
          "bye" => if(p.black_player == nil, do: "bye")
        }
      end)

    payload = %{
      "tournament" => %{
        "id" => t.id,
        "name" => t.name,
        "city" => t.city || "",
        "dates" => dates(t)
      },
      "round" => round.number,
      "rounds" => t.rounds_count,
      "published_at" => round.published_at && DateTime.to_iso8601(round.published_at),
      "locale" => locale,
      "rating_label" => rating_label(t),
      "team" => Tournament.team?(t),
      "boards" => boards
    }

    Map.put(payload, "rev", rev(payload))
  end

  @doc """
  The payload as an announcer in `room` (a `PairingsEngine.Rooms` room, or
  nil) gets it: only the boards that room holds, and a `"room"` key with
  its name, with the `rev` worked out again. No room, no change. A nil
  payload stays nil.
  """
  def for_room(nil, _room), do: nil
  def for_room(payload, nil), do: payload

  def for_room(payload, room) do
    payload
    |> Map.update!("boards", fn boards ->
      Enum.filter(boards, &PairingsEngine.Rooms.holds?(room, &1["board"]))
    end)
    |> Map.put("room", room.name)
    |> then(&Map.put(&1, "rev", rev(&1)))
  end

  @doc "The payload's revision: hex SHA-256 of its canonical JSON."
  def rev(payload) do
    payload
    |> Map.delete("rev")
    |> canonical()
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc ~S(The name to say aloud: "Carlsen, Magnus" becomes "Magnus Carlsen"; no comma, no change.)
  def spoken(nil), do: ""

  def spoken(name) when is_binary(name) do
    case String.split(name, ",", parts: 2) do
      [last, first] ->
        case String.trim(first) do
          "" -> String.trim(last)
          first -> first <> " " <> String.trim(last)
        end

      [_] ->
        String.trim(name)
    end
  end

  @doc ~S("nl" when the owner's account language starts with nl, "en" otherwise.)
  def locale(%Tournament{user: %{locale: "nl" <> _}}), do: "nl"
  def locale(_tournament), do: "en"

  defp player(nil, _t, _scores), do: nil

  defp player(%Player{} = p, t, scores) do
    %{
      "name" => p.name,
      "spoken" => spoken(p.name),
      "title" => p.title || "",
      "rating" => rating(Player.rating(p, t.rating_method)),
      "federation" => p.federation || "",
      "club" => p.club || "",
      "number" => p.pairing_number,
      "score" => score(Map.get(scores, p.id, 0.0))
    }
  end

  # 0 for unrated, as the Polis plugin sends it: the payloads are one shape.
  defp rating(n) when is_integer(n), do: n
  defp rating(_unrated), do: 0

  defp score(v) when is_float(v) do
    if v == Float.round(v, 0), do: Integer.to_string(trunc(v)), else: Float.to_string(v)
  end

  defp score(v) when is_integer(v), do: Integer.to_string(v)
  defp score(v), do: to_string(v)

  # The printed list's column header (the print controller's own reading,
  # private there), untranslated so both hall plugins send the same bytes:
  # "Elo" where FIDE leads, "Nat." for a national list, "Rtg" otherwise.
  defp rating_label(%{rating_method: method}) when method in ["FIDE", "FIDON", nil], do: "Elo"
  defp rating_label(%{rating_method: method}) when method in ["NRO", "NIDOF"], do: "Nat."
  defp rating_label(_t), do: "Rtg"

  defp dates(%Tournament{start_date: from, end_date: to}) do
    case {blank(from), blank(to)} do
      {nil, nil} -> ""
      {from, nil} -> from
      {nil, to} -> to
      {same, same} -> same
      {from, to} -> from <> " - " <> to
    end
  end

  defp blank(nil), do: nil

  defp blank(text) when is_binary(text) do
    case String.trim(text) do
      "" -> nil
      text -> text
    end
  end

  defp canonical(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {to_string(k), canonical(v)} end)
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(other), do: other
end
