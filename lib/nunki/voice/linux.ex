defmodule Nunki.Voice.Linux do
  @moduledoc """
  Linux: `espeak-ng`, or `spd-say` (speech-dispatcher) when that is all
  the system has.

      espeak-ng -v <voice or language> -f <file>
      espeak-ng --voices=<language>            a table, one voice a row
      sh -c 'exec spd-say -w -e -l "$1" < "$2"' nunki-speak <language> <file>

  espeak-ng is not installed by default on most systems:
  `sudo apt install espeak-ng` (install.sh says so when it is missing). Its
  voices are robotic and perfectly clear, which in a noisy hall is the part
  that matters.

  `spd-say` reads its text from standard input with `-e`; the shell is only
  there to point standard input at the file. The language and the file's
  name are the shell's arguments (`$1`, `$2`), never part of its script, so
  nothing in them is ever run.
  """

  @behaviour Nunki.Voice

  @impl true
  def engine(env) do
    cond do
      env.find.("espeak-ng") -> "espeak-ng"
      env.find.("spd-say") -> "spd-say"
      true -> nil
    end
  end

  @impl true
  def voices(env) do
    case engine(env) do
      "espeak-ng" ->
        espeak = env.find.("espeak-ng")

        voices =
          for lang <- ["en", "nl"],
              {out, 0} <- [env.cmd.(espeak, ["--voices=#{lang}"], stderr_to_stdout: true)],
              voice <- parse(out),
              do: voice

        {:ok, Enum.uniq_by(voices, & &1.id)}

      # speech-dispatcher chooses its own voice for a language.
      "spd-say" ->
        {:ok, []}

      nil ->
        {:error, :no_espeak}
    end
  end

  @impl true
  def command(text_file, voice, lang, env) do
    case engine(env) do
      "espeak-ng" ->
        {:ok, {env.find.("espeak-ng"), ["-v", voice || lang, "-f", text_file]}}

      "spd-say" ->
        sh = env.find.("sh") || "/bin/sh"

        {:ok, {sh, ["-c", ~s(exec spd-say -w -e -l "$1" < "$2"), "nunki-speak", lang, text_file]}}

      nil ->
        {:error, :no_espeak}
    end
  end

  @doc false
  # espeak-ng --voices=nl:
  #   Pty Language       Age/Gender VoiceName          File                 Other Languages
  #    5  nl              --/M      Dutch              gmw/nl               (af 9)
  # The language column is what `-v` is given: espeak-ng takes it for its
  # own voice of that language.
  def parse(output) do
    output
    |> String.split(["\r\n", "\n"], trim: true)
    |> Enum.drop_while(&(not String.starts_with?(String.trim_leading(&1), "Pty")))
    |> Enum.drop(1)
    |> Enum.flat_map(fn line ->
      case String.split(line) do
        [_pty, lang, _age_gender, name | _rest] ->
          [%{id: lang, lang: lang, label: "#{String.replace(name, "_", " ")} (#{lang})"}]

        _other ->
          []
      end
    end)
  end
end
