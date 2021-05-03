defmodule Backoffice.LayoutView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice


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

  def render_links(conn, links, indent \\ 1) do
    for link <- links do
      case Map.has_key?(link, :links) do
        true ->
          [
            {:safe, ~s(<span x-data="{ expanded: #{Map.get(link, :expanded, false)} }">)},
            {:safe,
             """
               <span
                @click="expanded = !expanded"
                class="#{active_link(conn.request_path, "")} ml-#{indent * 2} cursor-pointer flex justify-between">
                <span class="flex">
                  #{render_icon(link[:icon])}
                  #{link.label}
                </span>
                <template x-if="expanded">
                  <svg class="h-5 w-5 mr-2" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />
                  </svg>
                </template>
                <template x-if="!expanded">
                  <svg class="h-5 w-5 mr-2 xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                  </svg>
                </template>
               </span>
             """},
            {:safe, ~s(<span x-show="expanded">)},
            render_links(conn, link.links, indent + 1),
            {:safe, ~s(</span>)},
            {:safe, ~s(</span>)}
          ]

        false ->
          link to: link.link,
               class: ["ml-#{indent * 2} " | active_link(conn.request_path, link.link)] do
            [
              {:safe, render_icon(link[:icon])},
              link.label
            ]
          end
      end
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
    "bg-gray-100 text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md"
  end

  def active_link(_, _) do
    "text-gray-600 hover:bg-gray-50 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md "
  end

  def render_icon(content) when not is_nil(content) do
    """
    <div class="h-4 w-4 fill-current mr-3">
      #{content}
    </div>
    """
  end

  def render_icon(_), do: ""
end
