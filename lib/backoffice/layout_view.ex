defmodule Backoffice.LayoutView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice

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

  def render_stylesheets do
    layout = Application.get_env(:backoffice, :layout)

    case layout && function_exported?(layout, :stylesheets, 0) do
      true -> layout.stylesheets()
      _ -> []
    end
  end

  def render_scripts do
    layout = Application.get_env(:backoffice, :layout)

    case layout && function_exported?(layout, :scripts, 0) do
      true -> layout.scripts()
      _ -> []
    end
  end

  def links do
    layout = Application.get_env(:backoffice, :layout)

    case layout && function_exported?(layout, :links, 0) do
      true -> layout.links()
      _ -> []
    end
  end

  def logo do
    layout = Application.get_env(:backoffice, :layout)

    case layout && function_exported?(layout, :logo, 0) do
      true -> layout.logo()
      _ -> "https://tailwindui.com/img/logos/workflow-logo-indigo-600-mark-gray-800-text.svg"
    end
  end

  def active_link(path, path) do
    {:safe,
     "bg-gray-100 text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md"}
  end

  def active_link(_, _) do
    {:safe,
     """
     text-gray-600 hover:bg-gray-50 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md
     """}
  end

  def render_icon(content) do
    {:safe,
     """
     <div class="h-4 w-4 fill-current mr-3">
       #{content}
     </div>
     """}
  end
end
