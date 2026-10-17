defmodule NunkiWeb.Gettext do
  @moduledoc """
  The pages' words, English and Dutch (`priv/gettext`). The announcements
  themselves are the `speech` domain, used by `Nunki.Script` with the
  locale of the tournament rather than the locale of whoever is looking.
  """
  use Gettext.Backend, otp_app: :nunki
end
