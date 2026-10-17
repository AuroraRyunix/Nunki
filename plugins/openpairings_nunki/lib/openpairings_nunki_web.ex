defmodule OpenPairingsNunkiWeb do
  @moduledoc """
  `use OpenPairingsNunkiWeb, :live_view`: what the core's
  `use PairingsEngineWeb, :live_view` gives a page, with the plugin's own
  message catalogue in place of the core's.
  """

  def live_view do
    quote do
      use Phoenix.LiveView
      use Gettext, backend: OpenPairingsNunki.Gettext

      import PairingsEngineWeb.CoreComponents

      alias PairingsEngineWeb.Layouts

      on_mount OpenPairingsNunkiWeb.Locale
    end
  end

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
end
