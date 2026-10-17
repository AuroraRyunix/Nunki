defmodule Nunki.Voice.MacOS do
  @moduledoc """
  macOS: `say`, which every Mac has.

      say -v <voice> -f <file>     reads the file aloud, returns when done
      say -v '?'                   one voice a line: name, locale, # sample

  Dutch voices (Xander, Claire, Ellen...) are there to download in System
  Settings, Accessibility, Spoken Content, System voice, Manage voices.
  Without one, `say` reads Dutch with an English voice, which is a
  remarkable sound and not a useful one; the control page says so.
  """

  @behaviour Nunki.Voice

  @impl true
  def engine(env), do: if(env.find.("say"), do: "say", else: nil)

  @impl true
  def voices(env) do
    with {:ok, say} <- exe(env),
         {out, 0} <- env.cmd.(say, ["-v", "?"], stderr_to_stdout: true) do
      {:ok, parse(out)}
    else
      {:error, reason} -> {:error, reason}
      {out, status} -> {:error, {:exit, status, String.slice(to_string(out), 0, 300)}}
    end
  end

  @impl true
  def command(text_file, voice, _lang, env) do
    with {:ok, say} <- exe(env) do
      voice_args = if voice in [nil, ""], do: [], else: ["-v", voice]
      {:ok, {say, voice_args ++ ["-f", text_file]}}
    end
  end

  @doc false
  # "Ellen               nl_BE    # Hallo, mijn naam is Ellen."
  # "Eddy (English (UK)) en_GB    # Hello! My name is Eddy."
  def parse(output) do
    output
    |> String.split(["\r\n", "\n"], trim: true)
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^(.+?)\s+([a-z]{2,3}[_-][A-Za-z0-9]+)\s+#/, line) do
        [_, name, locale] ->
          name = String.trim(name)
          [%{id: name, lang: String.replace(locale, "_", "-"), label: "#{name} (#{locale})"}]

        nil ->
          []
      end
    end)
  end

  defp exe(env) do
    case env.find.("say") do
      nil -> {:error, :no_say}
      say -> {:ok, say}
    end
  end
end
