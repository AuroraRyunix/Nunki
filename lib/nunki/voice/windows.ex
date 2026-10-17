defmodule Nunki.Voice.Windows do
  @moduledoc """
  Windows: Windows PowerShell 5.1 running `priv/voice/windows.ps1`.

  Windows PowerShell and not PowerShell 7: 5.1 is on every Windows 10 and
  11 and can reach WinRT, 7 is on few hall PCs and cannot. The script
  prefers WinRT's `Windows.Media.SpeechSynthesis.SpeechSynthesizer` - the
  OneCore voices, which is where the Dutch voice goes when the Dutch speech
  pack is added (Settings, Time and language, Speech) - synthesises to a WAV
  file and plays it with `System.Media.SoundPlayer.PlaySync()`. Where WinRT
  is not there it falls back to System.Speech (SAPI), whose voices are
  fewer and usually English only.

      powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass
        -File <priv>/voice/windows.ps1 -Action speak -TextFile <file> -Lang nl [-Voice <id>]
      ... -Action list        one voice a line: id TAB language TAB engine

  The text is in the file, read by the script as UTF-8; nothing said is
  ever part of the command.
  """

  @behaviour Nunki.Voice

  @impl true
  def engine(env) do
    if powershell(env), do: "Windows", else: nil
  end

  @impl true
  def voices(env) do
    with {:ok, exe} <- exe(env),
         {out, 0} <- env.cmd.(exe, base_args(env) ++ ["-Action", "list"], stderr_to_stdout: false) do
      {:ok, parse(out)}
    else
      {:error, reason} -> {:error, reason}
      {out, status} -> {:error, {:exit, status, String.slice(to_string(out), 0, 300)}}
    end
  end

  @impl true
  def command(text_file, voice, lang, env) do
    with {:ok, exe} <- exe(env) do
      voice_args = if voice in [nil, ""], do: [], else: ["-Voice", voice]

      {:ok,
       {exe,
        base_args(env) ++
          ["-Action", "speak", "-TextFile", text_file, "-Lang", lang] ++ voice_args}}
    end
  end

  @doc false
  # One voice a line: "Microsoft Frank\tnl-NL\twinrt".
  def parse(output) do
    output
    |> String.split(["\r\n", "\n"], trim: true)
    |> Enum.flat_map(fn line ->
      case String.split(line, "\t") do
        [id, lang | rest] when id != "" and lang != "" ->
          engine = List.first(rest) || ""
          suffix = if engine == "sapi", do: ", SAPI", else: ""
          [%{id: id, lang: lang, label: "#{id} (#{lang}#{suffix})"}]

        _other ->
          []
      end
    end)
    |> Enum.uniq_by(& &1.id)
  end

  defp exe(env) do
    case powershell(env) do
      nil -> {:error, :no_powershell}
      exe -> {:ok, exe}
    end
  end

  # Windows PowerShell 5.1 by its full path, so that a PowerShell 7 earlier
  # on PATH is not taken for it; PATH only when Windows is somewhere odd.
  defp powershell(env) do
    root = env.env.("SystemRoot") || "C:\\Windows"
    full = Path.join([root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"])

    if env.exists?.(full), do: full, else: env.find.("powershell")
  end

  defp base_args(_env) do
    ~w(-NoProfile -NonInteractive -ExecutionPolicy Bypass -File) ++ [script()]
  end

  @doc "Where the script is."
  def script, do: Application.app_dir(:nunki, "priv/voice/windows.ps1")
end
