defmodule OpenPairingsNunki.Announcer do
  @moduledoc """
  One hall announcer joined to one tournament. `key_hash` is the SHA-256 of
  the key the device was given when it joined; the key itself is nowhere on
  this server. `status` is whatever the device last reported (its voice,
  whether it is speaking), small and taken at its word.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "nunki_announcers" do
    field :device_id, :string
    field :name, :string, default: ""
    field :software, :string, default: ""
    field :key_hash, :binary, redact: true
    field :status, :map, default: %{}
    field :connected, :boolean, default: false
    field :last_seen_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :tournament, PairingsEngine.Tournaments.Tournament

    timestamps(type: :utc_datetime)
  end
end
