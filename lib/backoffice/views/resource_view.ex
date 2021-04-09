defmodule Backoffice.ResourceView do
  use Phoenix.HTML

  use Phoenix.View,
    root: "lib/backoffice/templates",
    namespace: Backoffice

  import Phoenix.LiveView.Helpers
  import Backoffice.ErrorHelper

  defdelegate form_field(form, field, opts), to: Backoffice.Field

  def fields_for(resource) do
    schema = Backoffice.Resources.resolve_schema(resource)

    fields = schema.__schema__(:fields)
    types = Enum.map(fields, &schema.__schema__(:type, &1))

    for {field, type} <- Enum.zip(fields, types), not is_tuple(type) do
      {field, %{type: type}}
    end
  end

  def get_class(%{class: class}), do: class

  def get_class(_) do
    "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
  end

  def sort_indicator(params, field) when is_atom(field) do
    sort_indicator(params, to_string(field))
  end

  def sort_indicator(%{"order_by" => <<"[desc]", field::binary>>}, field) do
    {:safe,
     """
     <svg class="mt-1 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4h13M3 8h9m-9 4h9m5-4v12m0 0l-4-4m4 4l4-4" />
     </svg>
     """}
  end

  def sort_indicator(%{"order_by" => <<"[asc]", field::binary>>}, field) do
    {:safe,
     """
     <svg class="mt-1 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12" />
     </svg>
     """}
  end

  def sort_indicator(_, _), do: ""

  def column_name({_field, %{label: label}}), do: label
  def column_name({field, _}), do: Phoenix.Naming.humanize(field)

  def column_value(resource, {_field, %{value: value}}) when is_function(value) do
    {:safe, value.(resource) || ""}
  end

  def column_value(resource, {field, %{type: :boolean}}) do
    {:safe,
     """
     <div class="flex items-center h-5">
        <input disabled #{Map.get(resource, field) && "checked"} type="checkbox" class="focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded">
      </div>
     """}
  end

  def column_value(resource, {field, %{type: :map}}) do
    Map.get(resource, field) |> Jason.encode!(pretty: true)
  end

  def column_value(resource, {field, _}) do
    Map.get(resource, field)
  end

  def action_name(action, opts) when is_map(opts) do
    case opts[:label] do
      nil -> Phoenix.Naming.humanize(action)
      label -> label
    end
  end

  def maybe_confirm(%{confirm: false}), do: ""
  def maybe_confirm(%{confirm: msg}), do: {:safe, ["data-confirm=", "\"", msg, "\""]}

  def live_modal(_socket, component, opts) do
    return_to = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: return_to, component: component, opts: opts]
    live_component(socket, Backoffice.ModalComponent, modal_opts)
  end

  def page_nav(socket, %{page: page}, params, route) do
    previous_params = Map.put(params, :page, page.page_number - 1)
    next_params = Map.put(params, :page, page.page_number + 1)

    ~e"""
      <nav class="bg-white px-4 py-3 flex items-center justify-between border-b border-gray-200 sm:px-6">
      <div>
        <p class="text-sm leading-5 text-gray-700">
          Showing
          <span class="font-medium">
            <%= (page.page_number * page.page_size - page.page_size) + 1 %>
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
      <div class="ml-3 flex-1 flex justify-end">
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
