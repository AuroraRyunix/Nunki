defmodule NunkiWeb do
  @moduledoc """
  Nunki's pages: the control page (`/`), the hall screen (`/hall`) and the
  help (`/help`). Three pages, on purpose; what is announced is decided in
  OpenPairings, and this is only where it is said out loud.
  """

  def static_paths, do: ~w(assets robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html]

      use Gettext, backend: NunkiWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Gettext, backend: NunkiWeb.Gettext

      import Phoenix.HTML
      import NunkiWeb.CoreComponents

      alias Phoenix.LiveView.JS
      alias NunkiWeb.Layouts

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: NunkiWeb.Endpoint,
        router: NunkiWeb.Router,
        statics: NunkiWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
end
