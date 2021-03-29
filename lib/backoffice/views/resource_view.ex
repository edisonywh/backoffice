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

  defp do_form_field(form, field, {:parameterized, Ecto.Enum, %{values: values}}, opts) do
    options = values |> Enum.map(&Phoenix.Naming.humanize/1) |> Enum.zip(values)

    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
        ],
        opts
      )

    select(form, field, options, opts)
  end

  defp do_form_field(form, field, {:embed, %{related: schema}}, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-2 mb-4 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
        ],
        opts
      )

    inputs_for(form, field, fn fp ->
      fields =
        for {k, v} <- schema.__changeset__() do
          {k, %{type: v}}
        end

      [
        {:safe, "<div class=\"p-2\">"},
        Enum.map(fields, fn {field, %{type: type}} ->
          [
            label(fp, field, class: "block text-sm font-medium leading-5 text-gray-700"),
            do_form_field(fp, field, type, opts)
          ]
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  defp do_form_field(form, field, {:assoc, %{related: schema}}, opts) do
    opts =
      Keyword.merge(
        [
          disabled: true,
          class:
            "bg-gray-200 mt-2 mb-4 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
        ],
        opts
      )

    inputs_for(form, field, fn fp ->
      fields = schema.__schema__(:fields)
      types = Enum.map(fields, &schema.__schema__(:type, &1))

      fields =
        for {k, v} <- Enum.zip(fields, types), not is_tuple(v) do
          {k, %{type: v}}
        end

      [
        {:safe, "<div class=\"p-2\">"},
        Enum.map(fields, fn {field, %{type: type}} ->
          [
            label(fp, field, class: "block text-sm font-medium leading-5 text-gray-700"),
            do_form_field(fp, field, type, opts)
          ]
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  # BUG: updating map field doesn't work now
  defp do_form_field(form, field, :map, opts) do
    opts =
      Keyword.merge(
        [
          class:
            "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition",
          value: inspect(input_value(form, field))
        ],
        opts
      )

    textarea(form, field, opts)
  end

  defp do_form_field(form, field, :boolean, opts) do
    opts =
      Keyword.merge(
        opts,
        class:
          "focus:ring-indigo-500 h-4 w-4 mt-2 mb-4 text-indigo-600 border-gray-300 rounded transition"
      )

    checkbox(form, field, opts)
  end

  # TODO: Would be nice to support LiveComponent for more complex component
  #   For example, I would like to have a drop-down suggestion logic as I type.
  # defp do_form_field(form, field, :component, opts) do
  # component = Keyword.fetch!(opts, :component)
  # opts = Keyword.merge(opts, form: form, field: field)

  # live_component(socket, component, opts)
  # end

  # Q: Are there any pitfall to allowing user render fields like this?
  defp do_form_field(form, field, :custom, opts) do
    slot = Keyword.fetch!(opts, :slot)

    slot.(form, field)
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
