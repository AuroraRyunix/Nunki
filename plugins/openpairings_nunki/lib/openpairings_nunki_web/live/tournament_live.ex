defmodule OpenPairingsNunkiWeb.TournamentLive do
  @moduledoc """
  `/p/nunki/tournaments/:id`: one tournament's hall announcers.

  The arbiter adds an announcer (a one-time join link, as text and as a QR
  code, valid fifteen minutes), sees which are online and what they said
  about themselves, removes one, and drives them: start the round
  countdown for the latest published round, cancel it, have the pairings
  read aloud, make them stop. The pairings themselves need no button -
  they reach the announcers the moment they are public.
  """
  use OpenPairingsNunkiWeb, :live_view

  alias OpenPairingsNunki.{Hall, Plugin}
  alias PairingsEngine.{Features, Mobile, Tournaments}

  @refresh_ms 15_000

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     assign(socket,
       page_title: gettext("Hall announcer"),
       enabled?: Features.enabled?(scope, Plugin.feature()),
       join: nil,
       note: nil,
       error: nil,
       countdown: nil,
       seconds_left: 0,
       ticking?: false,
       latest_round: 0,
       announcers_count: 0,
       countdown_form:
         to_form(%{"minutes" => to_string(Hall.default_countdown_minutes())}, as: :countdown)
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    tournament = Tournaments.get_authorized_tournament!(socket.assigns.current_scope, id)

    if connected?(socket) do
      Hall.subscribe(tournament.id)
      Phoenix.PubSub.subscribe(PairingsEngine.PubSub, Tournaments.tournament_topic(tournament.id))
      Process.send_after(self(), :refresh, @refresh_ms)
    end

    {:noreply, socket |> assign(tournament: tournament) |> load()}
  end

  ## ---------- events ----------

  # The buttons are not drawn with the feature off; a button that is not
  # drawn is still an event anybody can send.
  @impl true
  def handle_event(_event, _params, %{assigns: %{enabled?: false}} = socket),
    do: {:noreply, assign(socket, error: off_text(), note: nil)}

  def handle_event("add", _params, socket) do
    {:ok, join} = Hall.create_join_code(socket.assigns.current_scope, socket.assigns.tournament)

    {:noreply,
     assign(socket, join: Map.put(join, :qr_svg, Mobile.qr_svg(join.url)), note: nil, error: nil)}
  end

  def handle_event("hide_join", _params, socket), do: {:noreply, assign(socket, join: nil)}

  def handle_event("remove", %{"id" => id}, socket) do
    case Hall.revoke(socket.assigns.current_scope, socket.assigns.tournament, id) do
      :ok ->
        {:noreply, socket |> assign(note: gettext("Announcer removed."), error: nil) |> load()}

      {:error, :not_found} ->
        {:noreply, assign(socket, error: gettext("That announcer is already gone."), note: nil)}
    end
  end

  def handle_event("choose_minutes", %{"countdown" => params}, socket),
    do: {:noreply, assign(socket, countdown_form: to_form(params, as: :countdown))}

  def handle_event("start_countdown", %{"countdown" => %{"minutes" => minutes} = params}, socket) do
    socket = assign(socket, countdown_form: to_form(params, as: :countdown))

    case Hall.start_countdown(
           socket.assigns.current_scope,
           socket.assigns.tournament,
           parse_minutes(minutes)
         ) do
      {:ok, cd} ->
        {:noreply,
         socket
         |> assign(
           note: gettext("Countdown started for round %{n}.", n: cd.round),
           error: nil
         )
         |> load()}

      {:error, reason} ->
        {:noreply, assign(socket, error: error_text(reason), note: nil)}
    end
  end

  def handle_event("cancel_countdown", _params, socket) do
    case Hall.cancel_countdown(socket.assigns.current_scope, socket.assigns.tournament) do
      :ok ->
        {:noreply, socket |> assign(note: gettext("Countdown cancelled."), error: nil) |> load()}

      {:error, :none} ->
        {:noreply,
         socket |> assign(error: gettext("No countdown is running."), note: nil) |> load()}
    end
  end

  def handle_event("read", _params, socket) do
    case Hall.read_aloud(socket.assigns.current_scope, socket.assigns.tournament) do
      {:ok, n} ->
        {:noreply, assign(socket, note: gettext("Reading round %{n} aloud.", n: n), error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: error_text(reason), note: nil)}
    end
  end

  def handle_event("stop", _params, socket) do
    :ok = Hall.stop_reading(socket.assigns.current_scope, socket.assigns.tournament)
    {:noreply, assign(socket, note: gettext("Asked the announcers to stop."), error: nil)}
  end

  ## ---------- messages ----------

  @impl true
  def handle_info({:nunki_changed, _tid}, socket), do: {:noreply, load(socket)}

  def handle_info({:tournament_changed, _tid, _hint}, socket), do: {:noreply, load(socket)}

  def handle_info(:tick, socket) do
    {:noreply, socket |> assign(ticking?: false) |> tick()}
  end

  # Online is "heard within 90 seconds", which goes stale on its own.
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, load(socket)}
  end

  # The sockets' own traffic on the same topic is not the page's business.
  def handle_info(_other, socket), do: {:noreply, socket}

  ## ---------- helpers ----------

  defp load(socket) do
    %{current_scope: scope, tournament: t} = socket.assigns
    announcers = Hall.list_announcers(scope, t)
    now = DateTime.utc_now(:second)
    rows = Enum.map(announcers, &row(&1, now))

    socket
    |> assign(
      countdown: Hall.current_countdown(t.id),
      latest_round: Tournaments.latest_published_round_number(t),
      announcers_count: length(rows)
    )
    |> stream(:announcers, rows, reset: true)
    |> tick()
  end

  defp row(a, now), do: %{id: a.id, announcer: a, online?: Hall.online?(a, now)}

  # One timer at a time, and only while a countdown runs.
  defp tick(socket) do
    case socket.assigns.countdown do
      nil ->
        assign(socket, seconds_left: 0)

      cd ->
        left = Hall.seconds_left(cd)

        socket =
          if left > 0 and connected?(socket) and not socket.assigns.ticking? do
            Process.send_after(self(), :tick, 1000)
            assign(socket, ticking?: true)
          else
            socket
          end

        if left > 0,
          do: assign(socket, seconds_left: left),
          else: assign(socket, countdown: nil, seconds_left: 0)
    end
  end

  defp parse_minutes(text) when is_binary(text) do
    case Integer.parse(text) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_minutes(_other), do: nil

  defp error_text(:no_round),
    do: gettext("No round is published yet. Publish the pairings first.")

  defp error_text(:minutes), do: gettext("Choose one of the lengths offered.")

  defp off_text, do: gettext("The hall announcer is switched off for your account.")

  defp clock(seconds), do: "#{div(seconds, 60)}:#{seconds |> rem(60) |> pad()}"

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"

  defp minute_options,
    do: Enum.map(Hall.countdown_minutes(), &{ngettext("1 minute", "%{count} minutes", &1), &1})

  defp when_text(nil), do: gettext("never")
  defp when_text(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")

  defp status_text(%{} = status) do
    voice = status["voice"]

    speaking =
      case status["speaking"] do
        true -> gettext("speaking")
        false -> gettext("quiet")
        _ -> nil
      end

    [voice, speaking] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" · ")
  end

  defp status_text(_status), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      publish_status={assigns[:publish_status]}
      update_notice={assigns[:update_notice]}
      flash={@flash}
      current_path={assigns[:current_path]}
      current_scope={@current_scope}
      tournament={@tournament}
      active="plugin:nunki"
    >
      <div class="page-header">
        <div>
          <h1>{gettext("Hall announcer")}</h1>

          <p class="subtitle" style="margin: 0">
            {gettext(
              "The announcers in the hall read each round's pairings aloud as soon as they are public, and show the countdown to the start of the round."
            )}
          </p>
        </div>
      </div>

      <p id="nunki-note" role="status" aria-live="polite" class={@note && "ok-note"}>{@note}</p>

      <p :if={@error} id="nunki-error" role="alert" class="error-note">{@error}</p>

      <section :if={!@enabled?} id="nunki-not-enabled" class="card">
        <p class="hint">
          {off_text()}
          <.link navigate="/users/features" id="nunki-features-link">
            {gettext("Switch it on in your settings.")}
          </.link>
        </p>
      </section>

      <%= if @enabled? do %>
        <section id="nunki-controls" class="card">
          <h2>{gettext("Round start")}</h2>

          <%= if @latest_round == 0 do %>
            <p id="nunki-no-round" class="hint">
              {gettext(
                "No round is published yet. The countdown and the reading aloud are for the latest published round."
              )}
            </p>
          <% else %>
            <p class="hint" id="nunki-latest-round">
              {gettext("Latest published round: %{n}.", n: @latest_round)}
            </p>
          <% end %>

          <%= if @countdown do %>
            <div id="nunki-countdown" class="nunki-countdown" style="margin: 8px 0">
              <p style="margin: 0">
                {gettext("Countdown for round %{n}:", n: @countdown.round)}
                <strong
                  id="nunki-countdown-clock"
                  style="font-variant-numeric: tabular-nums; font-size: 1.4em"
                >
                  {clock(@seconds_left)}
                </strong>
              </p>

              <div class="actions">
                <button
                  type="button"
                  class="pe-btn"
                  id="nunki-cancel-countdown"
                  phx-click="cancel_countdown"
                >
                  {gettext("Cancel the countdown")}
                </button>
              </div>
            </div>
          <% else %>
            <.form
              for={@countdown_form}
              id="nunki-countdown-form"
              phx-change="choose_minutes"
              phx-submit="start_countdown"
              class="form-grid"
            >
              <.input
                field={@countdown_form[:minutes]}
                type="select"
                label={gettext("Countdown")}
                options={minute_options()}
              />
              <div class="actions">
                <button
                  type="submit"
                  class="pe-btn primary"
                  id="nunki-start-countdown"
                  disabled={@latest_round == 0}
                >
                  {gettext("Start the countdown")}
                </button>
              </div>
            </.form>
          <% end %>

          <div class="actions" style="margin-top: 8px">
            <button
              type="button"
              class="pe-btn"
              id="nunki-read"
              phx-click="read"
              disabled={@latest_round == 0}
            >
              {gettext("Read the pairings aloud")}
            </button>

            <button type="button" class="pe-btn" id="nunki-stop" phx-click="stop">
              {gettext("Stop reading")}
            </button>
          </div>
        </section>

        <section id="nunki-announcers" class="card">
          <h2>{gettext("Announcers")}</h2>

          <p :if={@announcers_count == 0} id="nunki-no-announcers" class="hint">
            {gettext("No announcer has joined this tournament yet.")}
          </p>

          <table :if={@announcers_count > 0} class="pe-table">
            <thead>
              <tr>
                <th scope="col">{gettext("Name")}</th>

                <th scope="col">{gettext("State")}</th>

                <th scope="col">{gettext("Last seen")}</th>

                <th scope="col">{gettext("Reports")}</th>

                <th scope="col"><span class="sr-only">{gettext("Actions")}</span></th>
              </tr>
            </thead>

            <tbody id="nunki-announcer-list" phx-update="stream">
              <tr :for={{dom_id, r} <- @streams.announcers} id={dom_id}>
                <td>
                  {if(r.announcer.name == "", do: r.announcer.device_id, else: r.announcer.name)}
                  <span :if={r.announcer.software != ""} class="hint">
                    &middot; {r.announcer.software}
                  </span>
                </td>

                <td id={"#{dom_id}-state"}>
                  <span class={if(r.online?, do: "ok-note", else: "hint")}>
                    {if(r.online?, do: gettext("online"), else: gettext("offline"))}
                  </span>
                </td>

                <td class="hint">{when_text(r.announcer.last_seen_at)}</td>

                <td class="hint" id={"#{dom_id}-status"}>{status_text(r.announcer.status)}</td>

                <td style="text-align: right">
                  <button
                    type="button"
                    class="pe-btn"
                    id={"nunki-remove-#{r.id}"}
                    phx-click="remove"
                    phx-value-id={r.id}
                    data-confirm={gettext("Remove this announcer? It forgets this tournament.")}
                  >
                    {gettext("Remove")}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>

          <div class="actions">
            <button type="button" class="pe-btn primary" id="nunki-add" phx-click="add">
              {gettext("Add an announcer")}
            </button>
          </div>

          <div :if={@join} id="nunki-join" style="margin-top: 12px">
            <p class="hint">
              {gettext(
                "Open Nunki on the hall PC, paste this link (or scan the code) and press Join. The link works once, until %{time}.",
                time: when_text(@join.expires_at)
              )}
            </p>

            <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap">
              <input
                type="text"
                readonly
                id="nunki-join-link"
                value={@join.url}
                style="flex: 1 1 24rem; min-width: 0; font-family: monospace"
              />
              <button
                type="button"
                class="pe-btn"
                id="nunki-copy-link"
                phx-hook=".CopyJoinLink"
                phx-update="ignore"
                data-target="nunki-join-link"
                data-copied={gettext("Copied")}
              >
                {gettext("Copy")}
              </button>
            </div>

            <div id="nunki-join-qr" style="margin-top: 8px; width: 240px; max-width: 100%">
              {Phoenix.HTML.raw(@join.qr_svg)}
            </div>

            <div class="actions">
              <button type="button" class="pe-btn" id="nunki-hide-join" phx-click="hide_join">
                {gettext("Done")}
              </button>
            </div>
          </div>
        </section>
      <% end %>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyJoinLink">
        export default {
          mounted() {
            this.el.addEventListener("click", () => {
              const input = document.getElementById(this.el.dataset.target)
              if (!input) return
              const done = () => {
                const label = this.el.textContent
                this.el.textContent = this.el.dataset.copied
                setTimeout(() => { this.el.textContent = label }, 1500)
              }
              if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(input.value).then(done, () => input.select())
              } else {
                input.select()
              }
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
