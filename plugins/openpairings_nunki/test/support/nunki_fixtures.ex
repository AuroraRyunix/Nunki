defmodule OpenPairingsNunki.Fixtures do
  @moduledoc """
  An administrator with the hall announcer switched on, a small tournament
  with its first round paired, and an announcer joined to it the way a
  hall PC would join: through a join code.
  """
  alias OpenPairingsNunki.{Hall, Plugin}
  alias PairingsEngine.{Accounts, Features, Pairing, Repo, Tournaments}
  alias PairingsEngine.Accounts.Scope

  @doc "Makes the context's user an administrator with the feature on."
  def setup_admin(%{user: user}) do
    {:ok, _} = Accounts.set_role(user.email, "admin")
    user = Accounts.get_user!(user.id)
    {:ok, user} = Features.set_enabled(user, [Plugin.feature()])
    %{user: user, scope: Scope.for_user(user)}
  end

  @doc "A tournament of five players (so there is a bye) with round 1 paired, not published."
  def tournament!(scope, attrs \\ %{}) do
    {:ok, t} =
      Tournaments.create_tournament(
        scope,
        Map.merge(
          %{
            "name" => "Open of Somewhere",
            "city" => "Somewhere",
            "round_dates" => [
              "2026-10-18",
              "2026-10-19",
              "2026-10-19",
              "2026-10-20",
              "2026-10-20"
            ],
            "rounds_count" => 5
          },
          attrs
        )
      )

    for {name, i} <-
          Enum.with_index(["Alpha, Anna", "Bravo, Bert", "Charlie", "Delta, Dirk", "Echo, Eva"]) do
      {:ok, _} =
        Tournaments.create_player(t.id, %{
          tournament_id: t.id,
          name: name,
          title: if(i == 0, do: "GM", else: ""),
          federation: "BEL",
          fide_rating: 2400 - 50 * i,
          fide_id: 30_000_000 + i
        })
    end

    {:ok, _} = Pairing.pair_next_round(Repo.reload!(t))
    Repo.reload!(t)
  end

  @doc "Publishes round `n` of `t` now."
  def publish!(t, n) do
    {:ok, round} = Tournaments.publish_round_now(Tournaments.get_round(t.id, n))
    round
  end

  @doc "Joins a device to `t` with a fresh code; the announcer and its key."
  def announcer!(scope, t, device \\ "device-1") do
    {:ok, %{code: code}} = Hall.create_join_code(scope, t)

    {:ok, %{announcer: a, key: key}} =
      Hall.redeem_join_code(code, %{
        "device" => device,
        "name" => "Hall PC",
        "software" => "nunki 0.1.0"
      })

    {a, key}
  end
end
