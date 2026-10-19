defmodule OpenPairingsNunkiWeb.PagesTest do
  @moduledoc """
  The plugin's two pages and its Settings entry: adding an announcer shows a
  link and a QR code, removing one tells it, and the round-start controls
  reach every announcer of the tournament.
  """
  use PairingsEngineWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import OpenPairingsNunki.Fixtures

  alias OpenPairingsNunki.{Announcer, Hall, Plugin}
  alias PairingsEngine.{Features, Repo, Tournaments}
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

  describe "the Settings entry" do
    test "is there with the feature on, and not without", %{scope: scope, user: user, t: t} do
      assert [%{id: "nunki", path: path, icon: icon, group: :publishing}] =
               Plugin.tournament_settings_entries(scope, t)

      assert path == "/p/nunki/tournaments/#{t.id}"
      assert icon == "hero-megaphone-micro"

      {:ok, user} = Features.set_enabled(user, [])
      assert Plugin.tournament_settings_entries(Scope.for_user(user), t) == []
    end

    test "the top bar no longer has one", %{scope: scope, t: t} do
      refute function_exported?(Plugin, :tournament_menu_entries, 2)

      refute Enum.any?(
               PairingsEngine.Plugins.tournament_menu_entries(scope, t),
               &(&1.id == "nunki")
             )
    end

    test "the feature is a general one" do
      assert [%{key: "nunki_hall_announcer", federation: "BEL"}] = Plugin.features()
    end
  end

  describe "the tournament page" do
    test "sits in the Settings frame, with the rail beside it", %{conn: conn, t: t} do
      view = page(conn, t)
      assert has_element?(view, "#settings-page")
      assert has_element?(view, "#settings-nav-plugin-nunki")
      assert has_element?(view, "#nunki-announcers")
    end

    test "with no rooms, offers only 'No room' and says where rooms are made",
         %{conn: conn, scope: scope, t: t} do
      {a, _key} = announcer!(scope, t)
      view = page(conn, t)

      assert has_element?(view, "#announcers-#{a.id}-no-rooms")
      assert has_element?(view, "#nunki-settings-#{a.id} select option", "No room")
      refute has_element?(view, "#nunki-settings-#{a.id} select option", "Main hall")
    end

    test "picks a room from the tournament's rooms and renames the announcer",
         %{conn: conn, scope: scope, t: t} do
      {:ok, t} =
        Tournaments.update_tournament(t, %{
          "rooms" => [%{"name" => "Main hall", "boards" => "1-2"}]
        })

      [room] = PairingsEngine.Rooms.list(t)
      {a, _key} = announcer!(scope, t)
      Hall.subscribe(t.id)
      view = page(conn, t)
      refute has_element?(view, "#announcers-#{a.id}-room")
      refute has_element?(view, "#announcers-#{a.id}-no-rooms")

      view
      |> form("#nunki-settings-#{a.id}", announcer: %{name: "Door PC", room_id: room.id})
      |> render_submit()

      id = a.id
      assert_receive {:nunki_settings_changed, ^id}
      assert has_element?(view, "#announcers-#{a.id}-name", "Door PC")
      assert has_element?(view, "#announcers-#{a.id}-room", "Main hall")
      assert %{name: "Door PC", room: "Main hall", room_id: rid} = Repo.get!(Announcer, a.id)
      assert rid == room.id

      # And back to none.
      view
      |> form("#nunki-settings-#{a.id}", announcer: %{room_id: ""})
      |> render_submit()

      refute has_element?(view, "#announcers-#{a.id}-room")
    end

    test "an unknown room id is refused", %{conn: conn, scope: scope, t: t} do
      {a, _key} = announcer!(scope, t)
      view = page(conn, t)

      render_submit(view, "save_settings", %{
        "announcer" => %{"id" => "#{a.id}", "room_id" => "nope"}
      })

      assert has_element?(view, "#nunki-error")
      assert Repo.get!(Announcer, a.id).room_id == ""
    end

    test "a legacy free-text room shows as a hint, not a choice",
         %{conn: conn, scope: scope, t: t} do
      {a, _key} = announcer!(scope, t)
      Repo.update_all(from(x in Announcer, where: x.id == ^a.id), set: [room: "Back room"])
      view = page(conn, t)

      assert has_element?(view, "#announcers-#{a.id}-room", "Back room")
      assert has_element?(view, "#announcers-#{a.id}-legacy-room", "Back room")
      refute has_element?(view, "#nunki-settings-#{a.id} select option", "Back room")
    end

    test "a change from the device shows up on the page", %{conn: conn, scope: scope, t: t} do
      {:ok, t} =
        Tournaments.update_tournament(t, %{"rooms" => [%{"name" => "Back room", "boards" => "1"}]})

      {a, _key} = announcer!(scope, t)
      view = page(conn, t)

      {:ok, _} = Hall.apply_settings(a, %{"room" => "back ROOM"})
      assert render(view) =~ "Back room"
      assert has_element?(view, "#announcers-#{a.id}-room", "Back room")
    end

    test "another tournament's announcer cannot be renamed here", %{
      conn: conn,
      scope: scope,
      t: t
    } do
      other = tournament!(scope, %{"name" => "Another Open"})
      {b, _key} = announcer!(scope, other, "device-2")
      view = page(conn, t)

      render_submit(view, "save_settings", %{
        "announcer" => %{"id" => "#{b.id}", "name" => "Hijack"}
      })

      assert has_element?(view, "#nunki-error")
      assert Repo.get!(Announcer, b.id).name == "Hall PC"
    end

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

    test "with the feature off an announcer that joined can still be removed", %{
      conn: conn,
      user: user,
      scope: scope,
      t: t
    } do
      {a, _key} = announcer!(scope, t)
      {:ok, _} = Features.set_enabled(user, [])
      Hall.subscribe(t.id)
      view = page(conn, t)

      assert has_element?(view, "#nunki-not-enabled")
      refute has_element?(view, "#nunki-add")

      view |> element("#nunki-remove-#{a.id}") |> render_click()
      assert Repo.get!(Announcer, a.id).revoked_at
    end

    test "with the feature off, nothing is sent", %{conn: conn, user: user, t: t} do
      publish!(t, 1)
      {a, _key} = announcer!(Scope.for_user(user), t)
      {:ok, _} = Features.set_enabled(user, [])
      Hall.subscribe(t.id)
      view = page(conn, t)

      assert has_element?(view, "#nunki-not-enabled")
      render_click(view, "read", %{})
      refute_received {:nunki_send, _}

      render_submit(view, "save_settings", %{
        "announcer" => %{"id" => "#{a.id}", "name" => "Nope"}
      })

      assert Repo.get!(Announcer, a.id).name == "Hall PC"
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
