defmodule PairingsEngine.Repo.Migrations.AddRoomToNunkiAnnouncers do
  use Ecto.Migration

  # Which room the announcer stands in, for halls with more than one.
  # Empty is a perfectly good answer; most halls have the one room.
  def change do
    alter table(:nunki_announcers) do
      add(:room, :string, null: false, default: "")
    end
  end
end
