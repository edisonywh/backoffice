defmodule Backoffice.LayoutView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice

  # TODO: Fix this part, it should be user-supplied.
  alias SlickWeb.Router.Helpers, as: Routes
end
