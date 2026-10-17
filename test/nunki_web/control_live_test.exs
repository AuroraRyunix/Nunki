defmodule NunkiWeb.ControlLiveTest do
  @moduledoc "The control page: the list, the join field, the speech settings and the buttons."

  use Nunki.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Nunki.{Announcer, Countdown, FakeServer, Speaker, Store}

  @endpoint NunkiWeb.Endpoint

  defp tournament(round \\ nil) do
    {:ok, id} =
      Store.add_tournament(%{
        "server" => "fake",
        "socket" => "ws://127.0.0.1:1/p/nunki/link",
        "key" => "k",
        "tournament" => %{"id" => "t-1", "name" => "Fake Open"}
      })

    if round,
      do:
        Store.update_tournament(
          id,
          &Map.merge(&1, %{"round" => round, "announced" => round["round"]})
        )

    id
  end

  test "an empty page says how to start, and has the join field" do
    {:ok, view, _html} = live(build_conn(), "/")
    assert has_element?(view, "#tournaments-empty")
    assert has_element?(view, "#join-form")
    assert has_element?(view, "#brand svg.logo")
    assert has_element?(view, "#hall-link[href='/hall']")
  end

  test "joining from the page puts the tournament in the list" do
    server = FakeServer.start()
    {:ok, view, _html} = live(build_conn(), "/")

    view |> form("#join-form", join: %{link: FakeServer.link(server)}) |> render_submit()

    [t] = Store.tournaments()
    assert has_element?(view, "#tournaments-#{t["id"]}")
    refute has_element?(view, "#join-error")
  end

  test "a bad link is said under the field, nothing joined" do
    {:ok, view, _html} = live(build_conn(), "/")

    view
    |> form("#join-form", join: %{link: "https://x.example/p/polis/join/AB"})
    |> render_submit()

    assert has_element?(view, "#join-error")
    assert Store.tournaments() == []
  end

  test "a joined tournament: its line, its round, Read now, a countdown, Remove" do
    id = tournament(payload(3))
    {:ok, view, _html} = live(build_conn(), "/")

    row = "#tournaments-#{id}"
    assert has_element?(view, "#{row} .dot.down")
    assert has_element?(view, "#{row}-round")

    view |> element("#{row}-read") |> render_click()
    eventually(fn -> "Pairings for round 3 are published." in Fake.texts() end)

    view
    |> form("#{row}-countdown-form", %{"tournament" => id, "minutes" => "5"})
    |> render_submit()

    assert %{round: 3, source: :local, remaining_ms: 300_000} = Countdown.get(id)
    assert has_element?(view, "#{row}-countdown")

    view |> element("#{row}-cancel") |> render_click()
    assert Countdown.get(id) == nil

    view |> element("#{row}-remove") |> render_click()
    assert Store.tournaments() == []
    assert has_element?(view, "#tournaments-empty")
  end

  test "Read now and the countdown need pairings first" do
    id = tournament()
    {:ok, view, _html} = live(build_conn(), "/")
    assert has_element?(view, "#tournaments-#{id}-read[disabled]")
    assert has_element?(view, "#tournaments-#{id}-countdown-start[disabled]")
  end

  test "the language override, the voice and read-on-publish are kept" do
    {:ok, view, _html} = live(build_conn(), "/")

    view
    |> form("#speech-form",
      speech: %{language: "nl", read_on_publish: "false", voice_nl: "Fake Vlaams"}
    )
    |> render_change()

    assert Store.setting("language") == "nl"
    assert Store.setting("read_on_publish") == false
    assert Store.setting("voices")["nl"] == "Fake Vlaams"
    assert Announcer.language(tournament()) == "nl"
  end

  test "Test voice speaks the test line in that language (with the fake)" do
    {:ok, view, _html} = live(build_conn(), "/")
    view |> element("#test-voice-nl") |> render_click()
    eventually(fn -> Fake.texts() == ["Zo klinkt de omroep in deze zaal."] end)
  end

  test "what is being said is on the page, and Stop stops it" do
    Fake.hold()
    {:ok, view, _html} = live(build_conn(), "/")
    Speaker.say(["Board 1: somebody against somebody else."], "en")
    eventually(fn -> has_element?(view, "#speaker-line") end)

    view |> element("#stop") |> render_click()
    refute Speaker.speaking?()
    eventually(fn -> has_element?(view, "#speaker-idle") end)
  end

  test "the update banner: install refused while busy, a second yes, later" do
    Nunki.Updates.Checker.put(%{
      version: "9.9.9",
      tag: "v9.9.9",
      url: "https://example.invalid",
      size: 10_485_760,
      asset: "a",
      no_build: false
    })

    on_exit(fn -> Nunki.Updates.Checker.forget() end)

    {:ok, view, _html} = live(build_conn(), "/")
    assert has_element?(view, "#update-banner")
    assert has_element?(view, "#update-banner-size")
    # Tests run as a copy that cannot update itself.
    assert has_element?(view, "#update-manual")
    refute has_element?(view, "#update-apply")

    view |> element("#update-later") |> render_click()
    refute has_element?(view, "#update-banner")
  end

  test "an installed copy: Install, refused while a countdown runs, then the second yes" do
    Application.put_env(:nunki, :install_kind, :velopack)
    me = self()
    Application.put_env(:nunki, :updates_stop_fun, fn code -> send(me, {:stopped, code}) end)
    Application.put_env(:nunki, :updates_stop_delay, 0)

    Nunki.Updates.Checker.put(%{
      version: "9.9.9",
      tag: "v9.9.9",
      url: "https://example.invalid",
      size: nil,
      asset: "NunkiApp-9.9.9-full.nupkg",
      no_build: false
    })

    on_exit(fn ->
      Nunki.Updates.Checker.forget()
      Application.put_env(:nunki, :install_kind, :manual)
      Application.delete_env(:nunki, :updates_stop_fun)
      Application.delete_env(:nunki, :updates_stop_delay)
    end)

    id = tournament()
    {:ok, _} = Countdown.start(id, 5, 900)

    {:ok, view, _html} = live(build_conn(), "/")
    view |> element("#update-apply") |> render_click()
    assert has_element?(view, "#update-busy")
    assert has_element?(view, "#update-force[data-confirm]")
    refute_received {:stopped, _}

    view |> element("#update-force") |> render_click()
    assert has_element?(view, "#update-going")
    assert_receive {:stopped, 90}
    Countdown.cancel(id)
  end

  test "Start with Windows is offered only to an installed Windows copy" do
    {:ok, view, _html} = live(build_conn(), "/")
    # config/test.exs: install_kind is :manual.
    refute has_element?(view, "#autostart")
  end

  test "the language switch is a form posting to /locale" do
    {:ok, view, _html} = live(build_conn(), "/")
    assert has_element?(view, "form#language[action='/locale'] button#lang-nl")

    conn = post(build_conn(), "/locale", %{"locale" => "nl", "return_to" => "/"})
    assert redirected_to(conn) == "/"
    {:ok, _view, html} = live(recycle(conn), "/")
    assert html =~ "Toernooien"
  end
end
