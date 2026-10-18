defmodule OpenPairingsNunki.Announcer do
  @moduledoc """
  One hall announcer joined to one tournament. `key_hash` is the SHA-256 of
  the key the device was given when it joined; the key itself is nowhere on
  this server. `status` is whatever the device last reported (its voice,
  whether it is speaking), small and taken at its word. `name` and the room
  are the one place the announcer's name and room live: the device and the
  tournament page both change them here, and the device is told.

  `room_id` points at one of the tournament's rooms (`PairingsEngine.Rooms`)
  and `room` keeps its name as last stored. The room that counts is the
  one `room_id` resolves to now, under its current name; see
  `OpenPairingsNunki.Hall.effective_room/2`. A row from before rooms has no
  `room_id` and a free-text `room`, which stays a label.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "nunki_announcers" do
    field :device_id, :string
    field :name, :string, default: ""
    field :room, :string, default: ""
    field :room_id, :string, default: ""
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
