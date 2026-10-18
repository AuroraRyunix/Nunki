defmodule OpenPairingsNunkiWeb.IndexLive do
  @moduledoc """
  `/p/nunki`: the hall announcers of every tournament this account can
  open, or, before there are any, what the plugin is and where to start.
  Everything is done on a tournament's own page; this one only points.
  """
  use OpenPairingsNunkiWeb, :live_view

  alias OpenPairingsNunki.{Hall, Plugin}
  alias PairingsEngine.Features

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    now = DateTime.utc_now(:second)

    rows =
      scope
      |> Hall.list_for_account()
      |> Enum.map(&%{id: &1.id, announcer: &1, online?: Hall.online?(&1, now)})

    {:ok,
     socket
     |> assign(
       page_title: gettext("Hall announcer (Nunki)"),
       enabled?: Features.enabled?(scope, Plugin.feature()),
       announcers_count: length(rows)
     )
     |> stream(:announcers, rows)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      publish_status={assigns[:publish_status]}
      update_notice={assigns[:update_notice]}
      flash={@flash}
      current_path={assigns[:current_path]}
      current_scope={@current_scope}
      active="plugin:nunki"
    >
      <div class="page-header">
        <div>
          <h1>{gettext("Hall announcer (Nunki)")}</h1>
          <p class="subtitle" style="margin: 0">
            {gettext(
              "Nunki runs on a PC in the playing hall with speakers. It shows the countdown to the start of the round and reads the pairings aloud, and it hears about each round from here the moment the pairings are public."
            )}
          </p>
        </div>
      </div>

      <section :if={!@enabled?} id="nunki-not-enabled" class="card">
        <p class="hint">
          {gettext("The hall announcer is switched off for your account.")}
          <.link navigate="/users/features" id="nunki-features-link">
            {gettext("Switch it on in your settings.")}
          </.link>
        </p>
      </section>

      <section id="nunki-all-announcers" class="card">
        <h2>{gettext("Your announcers")}</h2>
        <p :if={@announcers_count == 0} id="nunki-none" class="hint">
          {gettext(
            "None yet. Open a tournament's Settings, choose \"Hall announcer\" and press \"Add an announcer\"."
          )}
        </p>
        <table :if={@announcers_count > 0} class="pe-table">
          <thead>
            <tr>
              <th scope="col">{gettext("Tournament")}</th>
              <th scope="col">{gettext("Name")}</th>
              <th scope="col">{gettext("State")}</th>
            </tr>
          </thead>
          <tbody id="nunki-announcer-list" phx-update="stream">
            <tr :for={{dom_id, r} <- @streams.announcers} id={dom_id}>
              <td>
                <.link navigate={"/p/nunki/tournaments/#{r.announcer.tournament_id}"}>
                  {r.announcer.tournament.name}
                </.link>
              </td>
              <td>
                {if(r.announcer.name == "", do: r.announcer.device_id, else: r.announcer.name)}
              </td>
              <td class={if(r.online?, do: "ok-note", else: "hint")}>
                {if(r.online?, do: gettext("online"), else: gettext("offline"))}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </Layouts.app>
    """
  end
end
