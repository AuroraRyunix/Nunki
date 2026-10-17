defmodule OpenPairingsNunkiWeb.PagesTest do
  @moduledoc """
  The plugin's two pages and its menu entry: adding an announcer shows a
  link and a QR code, removing one tells it, and the round-start controls
  reach every announcer of the tournament.
  """
  use PairingsEngineWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import OpenPairingsNunki.Fixtures

  alias OpenPairingsNunki.{Hall, Plugin}
  alias PairingsEngine.Features
  alias PairingsEngine.Accounts.Scope

  setup :register_and_log_in_user
  setup :setup_admin

  setup %{scope: scope} do
    %{t: tournament!(scope)}
  end

  defp page(conn, t) do
    {:ok, view, _html} = live(conn, "/p/nunki/tournaments/#{t.id}")
    view
  end

  describe "the menu" do
    test "has the entry with the feature on, and not without", %{scope: scope, user: user, t: t} do
      assert [%{id: "nunki", path: path}] = Plugin.tournament_menu_entries(scope, t)
      assert path == "/p/nunki/tournaments/#{t.id}"

      {:ok, user} = Features.set_enabled(user, [])
      assert Plugin.tournament_menu_entries(Scope.for_user(user), t) == []
    end

    test "the feature is a general one" do
      assert [%{key: "nunki_hall_announcer", federation: nil}] = Plugin.features()
    end
  end

  describe "the tournament page" do
    test "adding an announcer shows a link and a QR code", %{conn: conn, t: t} do
      view = page(conn, t)
      refute has_element?(view, "#nunki-join")

      view |> element("#nunki-add") |> render_click()
      assert has_element?(view, "#nunki-join-link[value*='/p/nunki/join/']")
      assert has_element?(view, "#nunki-join-qr svg")
    end

    test "lists an announcer and removes it, telling it", %{conn: conn, scope: scope, t: t} do
      {a, _key} = announcer!(scope, t)
      Hall.subscribe(t.id)
      view = page(conn, t)

      assert has_element?(view, "#announcers-#{a.id}")
      assert has_element?(view, "#announcers-#{a.id}-state", "offline")

      view |> element("#nunki-remove-#{a.id}") |> render_click()
      id = a.id
      assert_receive {:nunki_revoked, ^id}
      refute has_element?(view, "#announcers-#{a.id}")
      assert has_element?(view, "#nunki-no-announcers")
    end

    test "the controls wait for a published round", %{conn: conn, t: t} do
      view = page(conn, t)
      assert has_element?(view, "#nunki-no-round")
      assert has_element?(view, "#nunki-start-countdown[disabled]")
      assert has_element?(view, "#nunki-read[disabled]")
    end

    test "start and cancel the countdown", %{conn: conn, t: t} do
      publish!(t, 1)
      Hall.subscribe(t.id)
      view = page(conn, t)

      view
      |> form("#nunki-countdown-form", countdown: %{minutes: "10"})
      |> render_submit()

      assert_receive {:nunki_send, %{type: "countdown", round: 1, seconds_left: 600, id: id}}
      assert has_element?(view, "#nunki-countdown-clock", "10:00")
      assert %{token: ^id} = Hall.current_countdown(t.id)

      view |> element("#nunki-cancel-countdown") |> render_click()
      assert_receive {:nunki_send, %{type: "countdown_cancel", id: ^id}}
      assert Hall.current_countdown(t.id) == nil
      assert has_element?(view, "#nunki-countdown-form")
    end

    test "a length the page does not offer is refused", %{conn: conn, t: t} do
      publish!(t, 1)
      view = page(conn, t)
      render_submit(view, "start_countdown", %{"countdown" => %{"minutes" => "7"}})
      assert has_element?(view, "#nunki-error")
      assert Hall.current_countdown(t.id) == nil
    end

    test "read the pairings aloud, and stop", %{conn: conn, t: t} do
      publish!(t, 1)
      Hall.subscribe(t.id)
      view = page(conn, t)

      view |> element("#nunki-read") |> render_click()
      assert_receive {:nunki_send, %{type: "read", round: 1}}

      view |> element("#nunki-stop") |> render_click()
      assert_receive {:nunki_send, %{type: "stop"}}
    end

    test "with the feature off, nothing is sent", %{conn: conn, user: user, t: t} do
      publish!(t, 1)
      {:ok, _} = Features.set_enabled(user, [])
      Hall.subscribe(t.id)
      view = page(conn, t)

      assert has_element?(view, "#nunki-not-enabled")
      render_click(view, "read", %{})
      refute_received {:nunki_send, _}
    end
  end

  describe "the overview" do
    test "lists the account's announcers", %{conn: conn, scope: scope, t: t} do
      {a, _} = announcer!(scope, t)
      {:ok, view, _} = live(conn, "/p/nunki")
      assert has_element?(view, "#announcers-#{a.id}")
    end

    test "says where to start without any", %{conn: conn} do
      {:ok, view, _} = live(conn, "/p/nunki")
      assert has_element?(view, "#nunki-none")
    end
  end
end
