defmodule PairingsEngine.Repo.Migrations.AddRoomIdToNunkiAnnouncers do
  use Ecto.Migration

  # Which of the tournament's rooms (PairingsEngine.Rooms) the announcer
  # stands in. `room` stays: it keeps the room's name, and for a row from
  # before rooms it keeps the free text somebody once typed.
  #
  # Nothing is migrated. A free-text room matches no room (no tournament
  # had any when it was typed), so it gets an empty `room_id` and goes on
  # acting as a label only: shown, never used to cut a round down to boards.
  # Pick a room for the announcer and the label is replaced by the real thing.
  def change do
    alter table(:nunki_announcers) do
      add(:room_id, :string, null: false, default: "")
    end
  end
end
