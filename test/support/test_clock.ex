defmodule Nunki.TestClock do
  @moduledoc """
  The tests' clock (`config :nunki, clock: Nunki.TestClock`): it stands
  still until a test moves it. Nobody waits for a countdown to run down.
  """
  @behaviour Nunki.Clock

  @key {__MODULE__, :now}

  @impl true
  def now_ms, do: :persistent_term.get(@key, 1_000_000)

  def set(ms), do: :persistent_term.put(@key, ms)

  def advance(ms), do: set(now_ms() + ms)
end
