defmodule OpenPairingsNunki.Countdown do
  @moduledoc """
  The round countdown running for a tournament: which round, when it ends,
  and the `token` the announcers know it by (the protocol's `id`). One row
  a tournament at most; starting another replaces it.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "nunki_countdowns" do
    field :round, :integer
    field :token, :string
    field :ends_at, :utc_datetime

    belongs_to :tournament, PairingsEngine.Tournaments.Tournament

    timestamps(type: :utc_datetime)
  end
end
