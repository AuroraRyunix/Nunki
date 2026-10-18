defmodule Nunki.CmdTest do
  @moduledoc """
  Commands with a deadline, programs that do not outlive whoever waited for
  them, and a Nunki that stops in seconds while a voice is still talking.

  The voice is `sleep` (`ping` on Windows): a program that takes thirty
  seconds and says nothing, which is `say` with a very long line. Nothing
  is said.
  """

  use Nunki.Case, async: false

  alias Nunki.Cmd

  defp slow do
    case :os.type() do
      {:win32, _} -> {"ping", ["-n", "30", "127.0.0.1"]}
      _unix -> {"sleep", ["30"]}
    end
  end

  defp quick do
    case :os.type() do
      {:win32, _} -> {"cmd", ["/c", "echo", "hello"]}
      _unix -> {"sh", ["-c", "echo hello"]}
    end
  end

  defp alive?(os_pid) do
    case :os.type() do
      {:win32, _} ->
        {out, _} = System.cmd("tasklist", ["/FI", "PID eq #{os_pid}", "/NH"])
        out =~ ~r/\b#{os_pid}\b/

      _unix ->
        match?({_, 0}, System.cmd("kill", ["-0", "#{os_pid}"], stderr_to_stdout: true))
    end
  end

  # Not Nunki.Case's eventually/2, which asks the Speaker and the store for
  # their state between tries: here they may well be stopped on purpose.
  defp gone?(os_pid, tries \\ 250) do
    cond do
      not alive?(os_pid) ->
        true

      tries == 0 ->
        false

      true ->
        receive do
        after
          20 -> gone?(os_pid, tries - 1)
        end
    end
  end

  test "a command that answers: its output and its status" do
    {exe, args} = quick()
    assert {out, 0} = Cmd.run(exe, args, timeout: 10_000)
    assert out =~ "hello"
    assert Nunki.Cmd.Reaper.watched() == []
  end

  test "a command that does not: stopped at the deadline, and killed" do
    {exe, args} = slow()
    started = System.monotonic_time(:millisecond)
    me = self()

    task =
      Task.async(fn ->
        send(me, :running)
        Cmd.run(exe, args, timeout: 500)
      end)

    assert_receive :running

    [os_pid] =
      eventually(fn -> match?([_], Nunki.Cmd.Reaper.watched()) && Nunki.Cmd.Reaper.watched() end)

    assert {out, :timeout} = Task.await(task, 5_000)
    assert out =~ "gave no answer"
    assert System.monotonic_time(:millisecond) - started < 4_000
    assert gone?(os_pid)
  end

  test "a caller that dies: its program dies with it" do
    {exe, args} = slow()
    pid = spawn(fn -> Cmd.run(exe, args, timeout: 60_000) end)

    [os_pid] =
      eventually(fn -> match?([_], Nunki.Cmd.Reaper.watched()) && Nunki.Cmd.Reaper.watched() end)

    Process.exit(pid, :kill)
    assert gone?(os_pid)
    eventually(fn -> Nunki.Cmd.Reaper.watched() == [] end)
  end

  test "a program that does not exist raises, as System.cmd does" do
    assert_raise ErlangError, fn -> Cmd.run("nunki-no-such-program", []) end
  end

  defmodule SlowVoice do
    @moduledoc false
    # A voice that is a real program which takes thirty seconds.
    def engine(_env), do: "slow"
    def voices(_env), do: {:ok, []}

    def command(_file, _voice, _lang, _env) do
      {exe, args} =
        case :os.type() do
          {:win32, _} -> {"ping", ["-n", "30", "127.0.0.1"]}
          _unix -> {"sleep", ["30"]}
        end

      {:ok, {System.find_executable(exe), args}}
    end
  end

  describe "a voice that is still talking" do
    setup do
      Application.put_env(:nunki, :voice_backend, SlowVoice)

      on_exit(fn ->
        Application.put_env(:nunki, :voice_backend, Nunki.Voice.Fake)
        {:ok, _} = Application.ensure_all_started(:nunki)
      end)
    end

    defp talking do
      Nunki.Speaker.say(["a very long line"], "en")
      eventually(fn -> match?([_], Nunki.Cmd.Reaper.watched()) && Nunki.Cmd.Reaper.watched() end)
    end

    test "a Speaker killed without a word: the voice goes with it" do
      [os_pid] = talking()
      Process.exit(Process.whereis(Nunki.Speaker), :kill)
      assert gone?(os_pid)
    end

    test "Nunki stops in seconds, and the voice with it" do
      [os_pid] = talking()
      {microseconds, :ok} = :timer.tc(fn -> Application.stop(:nunki) end)
      assert div(microseconds, 1000) < 3_000
      assert gone?(os_pid)
    end
  end
end
