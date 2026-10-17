defmodule OpenPairingsNunkiWeb.LinkSocketTest do
  @moduledoc """
  The announcer's link, its `WebSock` callbacks driven directly with the
  test process standing in for the socket process: hello and its answers,
  the round on welcome and on publication (once), the countdown restated,
  the page's commands, and removal.
  """
  use PairingsEngineWeb.ConnCase, async: false

  import Ecto.Query
  import OpenPairingsNunki.Fixtures

  alias OpenPairingsNunki.{Announcer, Countdown, Hall}
  alias OpenPairingsNunkiWeb.LinkSocket
  alias PairingsEngine.Repo

  setup :register_and_log_in_user
  setup :setup_admin

  setup %{scope: scope} do
    t = tournament!(scope)
    {a, key} = announcer!(scope, t)
    %{t: t, announcer: a, key: key}
  end

  defp hello(device, key, v \\ 1) do
    frame =
      Jason.encode!(%{
        type: "hello",
        v: v,
        device: device,
        key: key,
        name: "Hall PC",
        software: "nunki 0.1.0"
      })

    LinkSocket.handle_in({frame, opcode: :text}, LinkSocket.new_state())
  end

  defp frames({:push, frames, _state}), do: frames |> List.wrap() |> Enum.map(&decode/1)
  defp frames({:stop, :normal, _code, frames, _state}), do: Enum.map(frames, &decode/1)

  defp decode({:text, json}), do: Jason.decode!(json)

  defp state({:push, _frames, state}), do: state
  defp state({:ok, state}), do: state

  defp welcomed(%{announcer: a, key: key}) do
    result = hello(a.device_id, key)
    assert {:push, _, _} = result
    result
  end

  describe "hello" do
    test "with a good key: welcome, and the announcer is online", %{t: t} = ctx do
      result = welcomed(ctx)
      assert [%{"type" => "welcome", "v" => 1, "tournament" => tour} | _] = frames(result)
      assert tour == %{"id" => t.id, "name" => t.name}

      a = Repo.get!(Announcer, ctx.announcer.id)
      assert a.connected
      assert Hall.online?(a)
    end

    test "with a wrong key: refused key", %{announcer: a} do
      result = hello(a.device_id, "not-the-key")
      assert [%{"type" => "refused", "reason" => "key"}] = frames(result)
    end

    test "with another device's id: refused key", %{key: key} do
      assert [%{"reason" => "key"}] = frames(hello("someone-else", key))
    end

    test "after removal: refused revoked", %{scope: scope, t: t, announcer: a, key: key} do
      :ok = Hall.revoke(scope, t, a.id)
      assert [%{"type" => "refused", "reason" => "revoked"}] = frames(hello(a.device_id, key))
    end

    test "in another protocol version: refused version", %{announcer: a, key: key} do
      assert [%{"reason" => "version"}] = frames(hello(a.device_id, key, 2))
    end

    test "nothing but hello is listened to before hello" do
      status = Jason.encode!(%{type: "status", voice: "x"})

      assert {:ok, %{announcer: nil}} =
               LinkSocket.handle_in({status, opcode: :text}, LinkSocket.new_state())
    end
  end

  describe "the round" do
    test "is not sent while round 1 is unpublished", ctx do
      assert [%{"type" => "welcome"}] = frames(welcomed(ctx))
    end

    test "is sent on welcome once published", %{t: t} = ctx do
      publish!(t, 1)

      assert [%{"type" => "welcome"}, %{"type" => "round", "round" => payload}] =
               frames(welcomed(ctx))

      assert payload["round"] == 1
      assert is_binary(payload["rev"])
    end

    test "a newly published round is sent once, and not again for the same rev", %{t: t} = ctx do
      state = ctx |> welcomed() |> state()
      tid = t.id

      publish!(t, 1)
      assert_receive {:tournament_changed, ^tid, _} = changed

      # Debounced: the nudge only arms a recheck.
      assert {:ok, %{recheck: ref} = state} = LinkSocket.handle_info(changed, state)
      assert is_reference(ref)
      # A second nudge in the same burst arms nothing new.
      assert {:ok, %{recheck: ^ref}} = LinkSocket.handle_info(changed, state)

      result = LinkSocket.handle_info(:recheck, state)
      assert [%{"type" => "round", "round" => %{"round" => 1}}] = frames(result)

      # Nothing changed: nothing sent.
      assert {:ok, state} = LinkSocket.handle_info(:recheck, state(result))
      assert state.last_round == 1
    end

    test "a round taken back is not sent", %{t: t} = ctx do
      publish!(t, 1)
      state = ctx |> welcomed() |> state()
      round = PairingsEngine.Tournaments.get_round(t.id, 1)
      {:ok, _} = PairingsEngine.Tournaments.unpublish_round(round)
      assert {:ok, _} = LinkSocket.handle_info(:recheck, state)
    end
  end

  describe "the countdown" do
    test "is restated after welcome with what is left of it", %{scope: scope, t: t} = ctx do
      publish!(t, 1)
      {:ok, cd} = Hall.start_countdown(scope, t, 5)

      assert [_welcome, _round, %{"type" => "countdown"} = c] = frames(welcomed(ctx))
      assert c["round"] == 1
      assert c["id"] == cd.token
      assert c["seconds_left"] in 290..300
    end

    test "is not restated once it has run out", %{scope: scope, t: t} = ctx do
      publish!(t, 1)
      {:ok, _} = Hall.start_countdown(scope, t, 1)

      Repo.update_all(from(c in Countdown, where: c.tournament_id == ^t.id),
        set: [ends_at: DateTime.add(DateTime.utc_now(:second), -5)]
      )

      assert [%{"type" => "welcome"}, %{"type" => "round"}] = frames(welcomed(ctx))
    end
  end

  describe "the page's commands" do
    setup %{t: t} = ctx do
      publish!(t, 1)
      %{state: ctx |> welcomed() |> state()}
    end

    defp pass_on(state) do
      assert_receive {:nunki_send, _frame} = msg
      [frame] = frames(LinkSocket.handle_info(msg, state))
      frame
    end

    test "each reaches the socket", %{scope: scope, t: t, state: state} do
      {:ok, cd} = Hall.start_countdown(scope, t, 2)

      assert %{"type" => "countdown", "round" => 1, "seconds_left" => 120, "id" => id} =
               pass_on(state)

      assert id == cd.token

      :ok = Hall.cancel_countdown(scope, t)
      assert %{"type" => "countdown_cancel", "id" => ^id} = pass_on(state)

      {:ok, 1} = Hall.read_aloud(scope, t)
      assert %{"type" => "read", "round" => 1} = pass_on(state)

      :ok = Hall.stop_reading(scope, t)
      assert %{"type" => "stop"} = pass_on(state)
    end

    test "a removed announcer is told leave", %{scope: scope, t: t, announcer: a, state: state} do
      :ok = Hall.revoke(scope, t, a.id)
      id = a.id
      assert_receive {:nunki_revoked, ^id} = msg

      result = LinkSocket.handle_info(msg, state)
      assert [%{"type" => "leave"}] = frames(result)
      assert {:stop, :normal, _, _, %{announcer: nil}} = result
    end

    test "status is kept, leave forgets, terminate marks offline", %{announcer: a, state: state} do
      status = Jason.encode!(%{type: "status", voice: "Ellen", speaking: true})
      assert {:ok, state} = LinkSocket.handle_in({status, opcode: :text}, state)
      assert Repo.get!(Announcer, a.id).status == %{"voice" => "Ellen", "speaking" => true}

      :ok = LinkSocket.terminate(:remote, state)
      refute Repo.get!(Announcer, a.id).connected

      leave = Jason.encode!(%{type: "leave"})
      assert {:stop, :normal, _} = LinkSocket.handle_in({leave, opcode: :text}, state)
      assert Repo.get(Announcer, a.id) == nil
    end
  end

  test "a plain GET of the link is not upgraded" do
    assert build_conn() |> get("/p/nunki/link") |> Map.get(:status) == 426
  end
end
