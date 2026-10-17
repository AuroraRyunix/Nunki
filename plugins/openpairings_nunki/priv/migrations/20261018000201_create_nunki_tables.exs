defmodule PairingsEngine.Repo.Migrations.CreateNunkiTables do
  use Ecto.Migration

  # The hall announcer plugin's own three tables. Additive only, like every
  # core migration: a build without the plugin never reads them, and a
  # database that once had the plugin keeps working without it.
  def change do
    # One announcer joined to one tournament. A hall PC joined to two
    # tournaments is two rows, each with its own key. Removed in
    # OpenPairings = `revoked_at` set, so the device is told why at its
    # next hello instead of being met with a shrug.
    create table(:nunki_announcers) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :device_id, :string, null: false
      add :name, :string, null: false, default: ""
      add :software, :string, null: false, default: ""
      # SHA-256 of the key. The key itself was shown once, to the device.
      add :key_hash, :binary, null: false
      add :status, :map, null: false, default: %{}
      add :connected, :boolean, null: false, default: false
      add :last_seen_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:nunki_announcers, [:tournament_id, :device_id])
    create unique_index(:nunki_announcers, [:key_hash])
    create index(:nunki_announcers, [:device_id])

    # "Add an announcer": a one-time code, stored as its SHA-256, valid for
    # fifteen minutes and one use.
    create table(:nunki_join_codes) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :code_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:nunki_join_codes, [:code_hash])
    create index(:nunki_join_codes, [:tournament_id])

    # The running round countdown, at most one per tournament, so an
    # announcer that reconnects halfway through is told how much is left.
    create table(:nunki_countdowns) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :round, :integer, null: false
      add :token, :string, null: false
      add :ends_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:nunki_countdowns, [:tournament_id])
  end
end
