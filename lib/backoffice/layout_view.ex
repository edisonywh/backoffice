defmodule Backoffice.LayoutView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice

  def render_icon(content) do
    {:safe,
     """
     <div class="h-4 w-4 fill-current mr-3">
       #{content}
     </div>
     """}
  end

  js_path = Path.join(__DIR__, "../../priv/static/js/app.js")
  css_path = Path.join(__DIR__, "../../priv/static/css/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js File.read!(js_path)
  @app_css File.read!(css_path)

  def render("app.js", _), do: @app_js
  def render("app.css", _), do: @app_css

  def live_socket_path(conn) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end
end
