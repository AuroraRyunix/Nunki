defmodule Nunki.UpdatesTest do
  @moduledoc """
  The update check and its refusals: the file each installation would
  fetch, the size said before anything is fetched, and no update while a
  countdown runs or Nunki speaks - unless somebody says yes twice.
  """

  use Nunki.Case, async: false

  alias Nunki.{Countdown, Speaker, Store, Updates}
  alias Nunki.Updates.Checker

  defp github(body, status \\ 200) do
    Application.put_env(:nunki, :updates_req_options,
      plug: fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, Jason.encode!(body))
      end
    )

    on_exit(fn -> Application.delete_env(:nunki, :updates_req_options) end)
  end

  defp release(version, assets) do
    %{
      "tag_name" => "v" <> version,
      "html_url" => "https://github.com/teapot-chess/Nunki/releases/tag/v" <> version,
      "assets" => Enum.map(assets, fn {name, size} -> %{"name" => name, "size" => size} end)
    }
  end

  describe "the file each installation fetches" do
    test "by system, as the release names them" do
      assert Updates.asset_name(:manual, "1.0.0", {:win32, :nt}) ==
               "nunki-windows-x86_64-portable.zip"

      assert Updates.asset_name(:systemd, "1.0.0", {:unix, :linux}) =~
               ~r/^nunki-linux-(x86_64|aarch64)\.tar\.gz$/

      assert Updates.asset_name(:velopack, "1.2.3") == "NunkiApp-1.2.3-full.nupkg"
    end

    test "the Mac's is the Apple Silicon zip" do
      case Updates.asset_name(:manual, "1.0.0", {:unix, :darwin}) do
        nil -> assert Updates.no_build?({:unix, :darwin})
        name -> assert name == "nunki-macos-aarch64.zip"
      end
    end
  end

  describe "asking GitHub" do
    test "a newer release, with the size of what this copy would download" do
      name = Updates.asset_name(:manual, "9.9.9")
      github(release("9.9.9", [{name, 31_457_280}, {"SHA256SUMS", 400}]))

      assert {:ok, %{version: "9.9.9", size: 31_457_280, asset: ^name}, _etag} = Updates.check()
    end

    test "the version that is running is not news; nonsense and errors are silence" do
      github(release(Updates.current_version(), []))
      assert {:current, _} = Updates.check()

      github(%{"message" => "rate limited"}, 403)
      assert Updates.check() == :error

      github(%{"tag_name" => "not-a-version"})
      assert Updates.check() == :error
    end
  end

  describe "applying" do
    setup do
      Checker.put(%{
        version: "9.9.9",
        tag: "v9.9.9",
        url: "u",
        size: 1,
        asset: "a",
        no_build: false
      })

      on_exit(fn -> Checker.forget() end)
      :ok
    end

    test "a copy that cannot update itself says so and does nothing" do
      assert Updates.apply() == {:error, :manual}
    end

    test "refused while a countdown runs or Nunki speaks; a second yes overrides" do
      Application.put_env(:nunki, :install_kind, :velopack)
      me = self()
      Application.put_env(:nunki, :updates_stop_fun, fn code -> send(me, {:stopped, code}) end)
      Application.put_env(:nunki, :updates_stop_delay, 0)

      on_exit(fn ->
        Application.put_env(:nunki, :install_kind, :manual)
        Application.delete_env(:nunki, :updates_stop_fun)
        Application.delete_env(:nunki, :updates_stop_delay)
      end)

      {:ok, t} =
        Store.add_tournament(%{
          "server" => "s",
          "socket" => "ws://127.0.0.1:1/x",
          "key" => "k",
          "tournament" => %{"id" => "1", "name" => "x"}
        })

      {:ok, _} = Countdown.start(t, 1, 900)
      assert Updates.apply() == {:error, {:busy, [:countdown]}}

      Countdown.cancel(t)
      Fake.hold()
      Speaker.say(["a line"], "en")
      eventually(fn -> Speaker.speaking?() end)
      assert Updates.apply() == {:error, {:busy, [:speaking]}}

      assert Updates.apply(force: true) == :ok
      assert_receive {:stopped, 90}
      refute_received {:stopped, _}
    end

    test "nothing known, nothing done" do
      Checker.forget()
      assert Updates.apply() == {:error, :nothing}
    end
  end

  describe "the notice" do
    test "there while the setting says ask, gone when switched off" do
      Checker.put(%{
        version: "9.9.9",
        tag: "v9.9.9",
        url: "u",
        size: 1,
        asset: "a",
        no_build: false
      })

      on_exit(fn -> Checker.forget() end)

      assert %{version: "9.9.9"} = Updates.notice()
      Updates.put_mode("never")
      assert Updates.notice() == nil
      Updates.put_mode("ask")
      Updates.later("9.9.9")
      assert Updates.notice() == nil
    end
  end
end
