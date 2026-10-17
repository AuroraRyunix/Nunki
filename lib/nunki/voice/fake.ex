defmodule Nunki.Voice.Fake do
  @moduledoc """
  A voice that writes down what it was asked to say and makes no sound:
  development and the tests. Nothing it does runs a program.

  Every utterance is kept (`utterances/0`, oldest first) with its language
  and voice. By default an utterance is over the moment it starts; `hold/0`
  keeps each one going until `finish/0`, so a test can see the queue
  behind it and stop it halfway.
  """

  @behaviour Nunki.Voice

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{said: [], hold?: false, current: nil} end, name: __MODULE__)
  end

  @impl true
  def engine(_env), do: "fake"

  @impl true
  def voices(_env) do
    {:ok,
     [
       %{id: "Fake English", lang: "en-GB", label: "Fake English (en-GB)"},
       %{id: "Fake Nederlands", lang: "nl-NL", label: "Fake Nederlands (nl-NL)"},
       %{id: "Fake Vlaams", lang: "nl-BE", label: "Fake Vlaams (nl-BE)"}
     ]}
  end

  @impl true
  def command(_file, _voice, _lang, _env), do: {:error, :fake}

  @doc false
  # Called by `Nunki.Voice.start/3` in place of a program.
  def start(text, voice, lang, owner) do
    ref = make_ref()

    hold? =
      Agent.get_and_update(__MODULE__, fn state ->
        said = state.said ++ [%{text: text, voice: voice, lang: lang}]
        current = if state.hold?, do: {ref, owner}, else: nil
        {state.hold?, %{state | said: said, current: current}}
      end)

    unless hold?, do: send(owner, {:voice_done, ref})
    {:ok, %{ref: ref, fake: true}}
  end

  @doc false
  def stop(%{ref: ref}) do
    Agent.update(__MODULE__, fn
      %{current: {^ref, _owner}} = state -> %{state | current: nil}
      state -> state
    end)
  end

  @doc "What was said, oldest first: `%{text, voice, lang}`."
  def utterances, do: Agent.get(__MODULE__, & &1.said)

  @doc "Just the texts."
  def texts, do: Enum.map(utterances(), & &1.text)

  @doc "Forgets what was said and stops holding."
  def reset, do: Agent.update(__MODULE__, fn _ -> %{said: [], hold?: false, current: nil} end)

  @doc "From now on each utterance lasts until `finish/0`."
  def hold, do: Agent.update(__MODULE__, &%{&1 | hold?: true})

  @doc "Ends the utterance being said, as if the voice had reached the full stop."
  def finish do
    case Agent.get_and_update(__MODULE__, &{&1.current, %{&1 | current: nil}}) do
      {ref, owner} ->
        send(owner, {:voice_done, ref})
        :ok

      nil ->
        :nothing
    end
  end
end
