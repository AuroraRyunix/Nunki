defmodule Nunki.VoiceTest do
  @moduledoc """
  Every backend's commands and voice lists, built against a pretend system.
  No program runs here: `cmd` answers from a table and records the call.
  """

  use ExUnit.Case, async: true

  alias Nunki.Voice
  alias Nunki.Voice.{Linux, MacOS, Windows}

  defp env(opts) do
    me = self()
    found = Keyword.get(opts, :found, %{})
    outputs = Keyword.get(opts, :outputs, %{})

    %{
      find: &Map.get(found, &1),
      exists?: &(&1 in Keyword.get(opts, :exists, [])),
      env: &Map.get(Keyword.get(opts, :vars, %{}), &1),
      cmd: fn exe, args, _opts ->
        send(me, {:ran, exe, args})
        Map.get(outputs, {exe, args}, {"", 1})
      end
    }
  end

  describe "Windows" do
    @ps "C:\\Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

    test "Windows PowerShell 5.1 by its full path, the text by file" do
      env = env(exists: [@ps], vars: %{"SystemRoot" => "C:\\Windows"})

      assert {:ok, {@ps, args}} =
               Windows.command("C:/data/speech/a.txt", "Microsoft Frank", "nl", env)

      assert [
               "-NoProfile",
               "-NonInteractive",
               "-ExecutionPolicy",
               "Bypass",
               "-File",
               script | rest
             ] =
               args

      assert String.ends_with?(script, "priv/voice/windows.ps1")

      assert rest == [
               "-Action",
               "speak",
               "-TextFile",
               "C:/data/speech/a.txt",
               "-Lang",
               "nl",
               "-Voice",
               "Microsoft Frank"
             ]
    end

    test "no voice chosen: no -Voice; no PowerShell anywhere: an error" do
      env = env(exists: [@ps], vars: %{"SystemRoot" => "C:\\Windows"})
      assert {:ok, {_, args}} = Windows.command("f.txt", nil, "en", env)
      refute "-Voice" in args

      assert Windows.command("f.txt", nil, "en", env([])) == {:error, :no_powershell}
    end

    test "PATH only when Windows is somewhere odd" do
      env = env(found: %{"powershell" => "D:/ps/powershell.exe"})
      assert {:ok, {"D:/ps/powershell.exe", _}} = Windows.command("f.txt", nil, "en", env)
    end

    test "the voice list: id, language, engine; SAPI ones say so" do
      out =
        "Microsoft Zira\ten-US\twinrt\r\nMicrosoft Frank\tnl-NL\twinrt\r\nMicrosoft David Desktop\ten-US\tsapi\r\n"

      args =
        ~w(-NoProfile -NonInteractive -ExecutionPolicy Bypass -File) ++
          [Windows.script(), "-Action", "list"]

      env =
        env(
          exists: [@ps],
          vars: %{"SystemRoot" => "C:\\Windows"},
          outputs: %{{@ps, args} => {out, 0}}
        )

      assert {:ok, voices} = Windows.voices(env)
      assert_received {:ran, @ps, ^args}

      assert voices == [
               %{id: "Microsoft Zira", lang: "en-US", label: "Microsoft Zira (en-US)"},
               %{id: "Microsoft Frank", lang: "nl-NL", label: "Microsoft Frank (nl-NL)"},
               %{
                 id: "Microsoft David Desktop",
                 lang: "en-US",
                 label: "Microsoft David Desktop (en-US, SAPI)"
               }
             ]
    end
  end

  describe "macOS" do
    test "say -v <voice> -f <file>" do
      env = env(found: %{"say" => "/usr/bin/say"})

      assert MacOS.command("/d/a.txt", "Xander", "nl", env) ==
               {:ok, {"/usr/bin/say", ["-v", "Xander", "-f", "/d/a.txt"]}}

      assert MacOS.command("/d/a.txt", nil, "nl", env) ==
               {:ok, {"/usr/bin/say", ["-f", "/d/a.txt"]}}
    end

    test "the voices from say -v '?'" do
      out = """
      Ellen               nl_BE    # Hallo, mijn naam is Ellen.
      Eddy (English (UK)) en_GB    # Hello! My name is Eddy.
      not a voice line
      """

      env =
        env(
          found: %{"say" => "/usr/bin/say"},
          outputs: %{{"/usr/bin/say", ["-v", "?"]} => {out, 0}}
        )

      assert {:ok,
              [
                %{id: "Ellen", lang: "nl-BE", label: "Ellen (nl_BE)"},
                %{id: "Eddy (English (UK))", lang: "en-GB"}
              ]} = MacOS.voices(env)
    end
  end

  describe "Linux" do
    test "espeak-ng -v <voice or language> -f <file>" do
      env = env(found: %{"espeak-ng" => "/usr/bin/espeak-ng"})

      assert Linux.command("/d/a.txt", nil, "nl", env) ==
               {:ok, {"/usr/bin/espeak-ng", ["-v", "nl", "-f", "/d/a.txt"]}}

      assert Linux.command("/d/a.txt", "nl-be", "nl", env) ==
               {:ok, {"/usr/bin/espeak-ng", ["-v", "nl-be", "-f", "/d/a.txt"]}}
    end

    test "spd-say when that is all there is: the language and file are arguments, not script" do
      env = env(found: %{"spd-say" => "/usr/bin/spd-say", "sh" => "/bin/sh"})

      assert {:ok, {"/bin/sh", ["-c", script, "nunki-speak", "nl", "/d/a.txt"]}} =
               Linux.command("/d/a.txt", nil, "nl", env)

      refute script =~ "a.txt"
      assert Linux.voices(env) == {:ok, []}
    end

    test "nothing to speak with is said, not crashed" do
      assert Linux.command("f", nil, "en", env([])) == {:error, :no_espeak}
      assert Linux.voices(env([])) == {:error, :no_espeak}
      assert Linux.engine(env([])) == nil
    end

    test "the voices from espeak-ng --voices=<lang>" do
      nl = """
      Pty Language       Age/Gender VoiceName          File                 Other Languages
       5  nl              --/M      Dutch              gmw/nl               (af 9)
      """

      en = """
      Pty Language       Age/Gender VoiceName          File                 Other Languages
       2  en-gb           --/M      English_(Great_Britain) gmw/en          (en 2)
      """

      exe = "/usr/bin/espeak-ng"

      env =
        env(
          found: %{"espeak-ng" => exe},
          outputs: %{{exe, ["--voices=en"]} => {en, 0}, {exe, ["--voices=nl"]} => {nl, 0}}
        )

      assert {:ok,
              [
                %{id: "en-gb", lang: "en-gb", label: "English (Great Britain) (en-gb)"},
                %{id: "nl", lang: "nl", label: "Dutch (nl)"}
              ]} = Linux.voices(env)
    end
  end

  describe "choosing" do
    test "the backend follows the system" do
      assert Voice.for_os({:win32, :nt}) == Windows
      assert Voice.for_os({:unix, :darwin}) == MacOS
      assert Voice.for_os({:unix, :linux}) == Linux
    end

    test "a chosen voice while it exists, else the first of the language" do
      voices = [
        %{id: "a", lang: "nl-NL", label: "a"},
        %{id: "b", lang: "nl-BE", label: "b"},
        %{id: "c", lang: "en-GB", label: "c"}
      ]

      assert Voice.resolve("nl", voices, %{"nl" => "b"}).id == "b"
      assert Voice.resolve("nl", voices, %{"nl" => "gone"}).id == "a"
      assert Voice.resolve("nl", voices, %{}).id == "a"
      assert Voice.resolve("en", voices, %{}).id == "c"
      assert Voice.resolve("nl", [], %{}) == nil
    end

    test "stop kills the whole tree on Windows and the process elsewhere" do
      me = self()
      run = fn exe, args, _ -> send(me, {:ran, exe, args}) end

      Voice.kill(4242, {:win32, :nt}, run)
      assert_received {:ran, "taskkill", ["/T", "/F", "/PID", "4242"]}

      Voice.kill(4242, {:unix, :linux}, run)
      assert_received {:ran, "kill", ["-TERM", "4242"]}
    end
  end
end
