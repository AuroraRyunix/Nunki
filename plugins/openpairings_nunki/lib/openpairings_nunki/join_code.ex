defmodule OpenPairingsNunki.JoinCode do
  @moduledoc """
  A one-time join code for one tournament, stored as its SHA-256: the code
  itself exists only in the link the arbiter was shown.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "nunki_join_codes" do
    field :code_hash, :binary, redact: true
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :tournament, PairingsEngine.Tournaments.Tournament
    belongs_to :created_by, PairingsEngine.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
