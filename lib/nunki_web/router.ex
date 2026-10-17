defmodule NunkiWeb.Router do
  use NunkiWeb, :router

  # No accounts and no PIN: Nunki listens on this machine only, unless
  # NUNKI_LISTEN=lan says otherwise, and then whoever is on the hall's
  # network may start a countdown. That is the trade, and the README says so.
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NunkiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug NunkiWeb.Locale
  end

  scope "/", NunkiWeb do
    pipe_through :browser

    # A form, not a link, so nothing a prefetching browser follows changes it.
    post "/locale", LocaleController, :set

    live_session :default, on_mount: {NunkiWeb.Locale, :default} do
      live "/", ControlLive, :index
      live "/hall", HallLive, :index
      live "/help", HelpLive, :index
    end
  end
end
