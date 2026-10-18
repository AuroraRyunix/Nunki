defmodule OpenPairingsNunki.Plugin do
  @moduledoc """
  Nunki, the hall announcer, as an OpenPairings plugin
  (`PairingsEngine.Plugin`).

  An arbiter joins an announcer (a hall PC with speakers running Nunki) to
  a tournament with a one-time link; from then on the announcer holds a
  WebSocket open to this server and hears about every round the moment its
  pairings become public. The arbiter starts the round countdown and the
  reading aloud from the plugin's tournament page. The announcer does the
  talking; this side only decides when.
  """
  @behaviour PairingsEngine.Plugin

  use Gettext, backend: OpenPairingsNunki.Gettext

  alias PairingsEngine.Features
  alias PairingsEngine.Tournaments.Tournament

  # Kept in step with the plugin's heading in the Nunki CHANGELOG.
  @version "0.1.0"

  @feature "nunki_hall_announcer"

  @doc "The `PairingsEngine.Features` key that switches the plugin on for an account."
  def feature, do: @feature

  @impl true
  def id, do: "nunki"

  @impl true
  def name, do: gettext("Hall announcer (Nunki)")

  @impl true
  def description,
    do:
      gettext(
        "Sends each round's pairings to the announcers in the hall the moment they are public, and lets you start the round countdown and the reading aloud from here."
      )

  @impl true
  def version, do: @version

  @impl true
  def start_path, do: "/p/nunki"

  @impl true
  def routes do
    [
      {"/", OpenPairingsNunkiWeb.IndexLive, :index},
      {"/tournaments/:id", OpenPairingsNunkiWeb.TournamentLive, :show}
    ]
  end

  @impl true
  def http_routes do
    [
      {:post, "/join/:code", OpenPairingsNunkiWeb.JoinPlug, []},
      {:get, "/link", OpenPairingsNunkiWeb.LinkPlug, []}
    ]
  end

  # The announcer is set up per tournament and then left alone, which is
  # what the Settings rail is for; the top bar is for what is used every day.
  # The icon is one the core's own source already uses (the stylesheet only
  # builds those), and a megaphone was already in.
  @impl true
  def tournament_settings_entries(scope, %Tournament{} = t) do
    if Features.enabled?(scope, @feature) do
      [
        %{
          id: "nunki",
          label: gettext("Hall announcer"),
          path: "/p/nunki/tournaments/#{t.id}",
          icon: "hero-megaphone-micro",
          group: :publishing
        }
      ]
    else
      []
    end
  end

  @impl true
  def features do
    [
      %{
        key: @feature,
        # The hosted edition is a Belgian server, and every plug-in on it
        # lives in the Belgian pack. "Optional tools for any federation" is
        # where nobody looks, as was pointed out with some force.
        federation: "BEL",
        label: gettext("Hall announcer (Nunki)"),
        description:
          gettext(
            "Adds \"Hall announcer\" to a tournament's Settings: join a hall PC running Nunki, and it reads each round's pairings aloud and shows the countdown to the start of the round."
          )
      }
    ]
  end

  @impl true
  def migrations_path, do: Path.expand("../../priv/migrations", __DIR__)
end
