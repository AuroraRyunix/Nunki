defmodule Nunki.Clock do
  @moduledoc """
  The countdown's clock: this machine's monotonic clock, in milliseconds.
  Monotonic because a countdown must not jump when the system's time is
  corrected under it, and this machine's own because the server only says
  how many seconds are left - never at what o'clock - so the two clocks
  never have to agree.

  `config :nunki, :clock` names another module with `now_ms/0`: the tests
  move time by hand instead of waiting for it.
  """

  @callback now_ms() :: integer()

  def now_ms do
    case Application.get_env(:nunki, :clock) do
      nil -> System.monotonic_time(:millisecond)
      module -> module.now_ms()
    end
  end
end
