defmodule Backoffice.LayoutView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice

  # TODO: Fix this part, it should be user-supplied.
  alias SlickWeb.Router.Helpers, as: Routes

  def render_icon(content) do
    {:safe,
     """
     <div class="h-4 w-4 fill-current mr-3">
       #{content}
     </div>
     """}
  end
end
