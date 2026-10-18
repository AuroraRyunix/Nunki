defmodule OpenPairingsNunki.Protocol do
  @moduledoc """
  The hall-link protocol, version 1, server side: the frames this plugin
  sends an announcer, and reading the ones it sends back. JSON text
  frames, each an object with a `"type"`. The rules are in the Nunki
  repository's `docs/protocol.md`; this module only spells them.
  """

  @version 1

  @doc "The protocol version this plugin speaks."
  def version, do: @version

  @doc "Whether a client's `v` is one this plugin speaks."
  def accepts?(v), do: v == @version

  @doc "Decodes a text frame to a map with a string `\"type\"`, or `{:error, :bad_frame}`."
  def decode(text) when is_binary(text) do
    case Jason.decode(text) do
      {:ok, %{"type" => type} = frame} when is_binary(type) -> {:ok, frame}
      _ -> {:error, :bad_frame}
    end
  end

  @doc "Encodes a frame for the wire."
  def encode(frame), do: Jason.encode!(frame)

  def welcome(server, tournament),
    do: %{
      type: "welcome",
      v: @version,
      server: server,
      tournament: %{id: tournament.id, name: tournament.name}
    }

  def refused(reason) when reason in ~w(version key revoked),
    do: %{type: "refused", reason: reason}

  def round(payload), do: %{type: "round", round: payload}

  def leave, do: %{type: "leave"}

  def countdown(round, seconds_left, id),
    do: %{type: "countdown", round: round, seconds_left: seconds_left, id: id}

  def countdown_cancel(id), do: %{type: "countdown_cancel", id: id}

  def read(round), do: %{type: "read", round: round}

  def stop, do: %{type: "stop"}

  def pong, do: %{type: "pong"}

  @doc """
  The announcer's name and room as this server holds them. Sent after
  `welcome` and whenever either changes; the server is the truth.
  """
  def settings(name, room), do: %{type: "settings", name: name, room: room}
end
