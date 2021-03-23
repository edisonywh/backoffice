defmodule Backoffice.ResourceView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice

  import Phoenix.LiveView.Helpers

  def form_field(form, field, opts) do
    type = Map.fetch!(opts, :type)
    opts = Map.get(opts, :opts, %{})

    do_form_field(form, field, type, Enum.into(opts, []))
  end

  defp maybe_disabled(opts) do
    case Keyword.get(opts, :disabled) do
      true -> "bg-gray-200"
      _ -> ""
    end
  end

  defp do_form_field(form, field, :integer, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
        ],
        opts
      )

    number_input(form, field, opts)
  end

  defp do_form_field(form, field, :textarea, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
        ],
        opts
      )

    textarea(form, field, opts)
  end

  defp do_form_field(form, field, :map, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition",
          value: Jason.encode!(input_value(form, field))
        ],
        opts
      )

    textarea(form, field, opts)
  end

  defp do_form_field(form, field, :boolean, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded transition"
        ],
        opts
      )

    checkbox(form, field, opts)
  end

  defp do_form_field(form, field, _type, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
        ],
        opts
      )

    text_input(form, field, opts)
  end

  def links do
    layout = Application.get_env(:backoffice, :layout)
    layout.links()
  end

  def logo do
    layout = Application.get_env(:backoffice, :layout)

    layout.logo() ||
      "https://tailwindui.com/img/logos/workflow-logo-indigo-600-mark-gray-800-text.svg"
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

  def column_name(field) when is_atom(field), do: column_name({field, nil})
  def column_name({field, nil}), do: Phoenix.Naming.humanize(field)

  def column_name({field, opts}) when is_map(opts) do
    case opts[:name] do
      nil -> column_name(field)
      name -> name
    end
  end

  def column_value(resource, {field, opts}) when is_map(opts) do
    column_value(resource, {field, opts[:value]})
  end

  def column_value(resource, {field, nil}), do: Map.get(resource, field)

  def column_value(resource, {_field, func}) when is_function(func) do
    data = func.(resource) || ""

    {:safe, data}
  end

  def action_name(field) when is_atom(field), do: action_name({field, nil})
  def action_name({field, nil}), do: Phoenix.Naming.humanize(field)

  def action_name({action, opts}) when is_map(opts) do
    case opts[:name] do
      nil -> Phoenix.Naming.humanize(action)
      name -> name
    end
  end

  def action_link({_action, opts}) do
    opts[:link]
  end

  def action_link({_action, opts}, resource) do
    case opts[:link] do
      link -> link.(resource)
    end
  end

  def live_modal(_socket, component, opts) do
    return_to = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: return_to, component: component, opts: opts]
    live_component(socket, Backoffice.ModalComponent, modal_opts)
  end

  def page_nav(socket, %{page: page} = _params, route) do
    previous_params = %{page: page.page_number - 1}
    next_params = %{page: page.page_number + 1}

    ~e"""
      <nav class="bg-white px-4 py-3 flex items-center justify-between border-b border-gray-200 sm:px-6">
      <div>
        <p class="text-sm leading-5 text-gray-700">
          Showing
          <span class="font-medium">
            <%= page.page_number * page.page_size - page.page_size %>
          </span>
          to
          <span class="font-medium">
            <%= min(page.total_entries, (page.page_number * page.page_size)) %>
          </span>
          of
          <span class="font-medium">
            <%= page.total_entries %>
          </span>
          results
        </p>
      </div>
      <div class="ml-3 flex-1 flex justify-between sm:justify-end">
        <%= if page.page_number > 1 do %>
          <%= live_patch "Previous", to: route.(socket, :index, previous_params), class: "ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm leading-5 font-medium rounded-md text-gray-700 bg-white hover:text-gray-500 focus:outline-none focus:shadow-outline-blue focus:border-blue-300 active:bg-gray-100 active:text-gray-700 transition ease-in-out duration-150" %>
        <% end %>
        <%= unless page.page_number == page.total_pages do %>
          <%= live_patch "Next", to: route.(socket, :index, next_params), class: "ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm leading-5 font-medium rounded-md text-gray-700 bg-white hover:text-gray-500 focus:outline-none focus:shadow-outline-blue focus:border-blue-300 active:bg-gray-100 active:text-gray-700 transition ease-in-out duration-150" %>
        <% end %>
      </div>
    </nav>
    """
  end
end
