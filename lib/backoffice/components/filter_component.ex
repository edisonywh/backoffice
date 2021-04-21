defmodule Backoffice.FilterComponent do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Phoenix.HTML.Form

  alias Backoffice.Field

  @default_debounce 500
  @datetime_fields ~w(naive_datetime naive_datetime_usec utc_datetime utc_datetime_usec time time_usec date)a

  @impl true
  def update(%{params: params, fields: fields}, socket) do
    params =
      params
      |> Map.drop(["page", "page_size", "order_by"])
      |> Backoffice.Resources.filterable_params(fields)

    filters =
      params
      |> Enum.map(&Backoffice.Filter.preprocess/1)
      |> List.flatten()
      |> Enum.reduce(fields, fn {_, field, _} = op, acc ->
        Keyword.update(acc, field, nil, fn map -> Map.put(map, :_filter, op) end)
      end)

    active_filters =
      Enum.filter(filters, fn {k, _v} ->
        Map.has_key?(params, to_string(k))
      end)

    socket =
      socket
      |> assign(:active_filters, active_filters)
      |> assign(:filterable, filters)
      |> assign(:params, params)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= f = form_for :filters, "#", [id: "filter_form", phx_change: :change, phx_target: @myself, phx_submit: :ignore] %>
    <div class="text-gray-500 text-sm p-4 rounded-lg border border-gray-200">
      <%= if Enum.empty?(@active_filters) do %>
        <p class="text-gray-500 mb-3">No active filters</p>
      <% else %>
        <%= for {field, val} <- Enum.reverse(@active_filters) do %>
          <div
          id='<%= "#{field}-#{System.unique_integer()}" %>'
          class="text-black w-auto flex items-center mb-3">
            <span
            phx-target="<%= @myself %>"
            phx-click="remove"
            phx-value-field="<%= field %>"
            class="w-1/12 text-gray-400 cursor-pointer">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </span>
            <span class="w-2/12"><%= name(field) %></span>
            <span class="w-auto flex"><%= inputs(f, field, val) %></span>
          </div>
        <% end %>
      <% end %>

      <p class="inline-flex">Filter by:</p>
      <%= for {field, _val} <- @filterable do %>
        <span phx-target="<%= @myself %>" phx-click="add" phx-value-field="<%= field %>" class="inline-flex rounded cursor-pointer border border-gray-200 hover:bg-gray-50 text-xs px-2.5 py-1.5 ml-2 mt-2">
          <%= name(field) %>
        </span>
      <% end %>
      </div>
      </form>
    """
  end

  def handle_event("ignore", params, socket) do
    handle_event("change", params, socket)
  end

  def handle_event("change", params, socket) do
    params =
      params
      |> Map.get("filters", %{})
      |> Map.merge(params)
      |> Map.drop(["_csrf_token", "_target", "filters"])
      |> Enum.reduce(%{}, fn
        {k, %{"operator" => operator, "value" => value}}, acc ->
          Map.put(acc, k, "#{operator_to_string(operator)}#{value}")

        {k, v}, acc ->
          Map.put(acc, k, v)
      end)

    url = Backoffice.Resources.get_path(socket.view, socket, :index, Enum.into(params, []))

    {:noreply, push_patch(socket, to: url)}
  end

  @impl true
  def handle_event("add", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    {field, val} = socket.assigns.filterable |> Enum.find(&match?({^field, _}, &1))

    params = Map.put(socket.assigns.params, field, default_value(val))

    {:noreply,
     push_patch(socket, to: Backoffice.Resources.get_path(socket.view, socket, :index, params))}
  end

  def handle_event("remove", %{"field" => field}, socket) do
    params = Map.drop(socket.assigns.params, [field])

    url = Backoffice.Resources.get_path(socket.view, socket, :index, Enum.into(params, []))

    {:noreply, push_patch(socket, to: url)}
  end

  defp inputs(form, field, %{type: Ecto.Enum, values: values, _filter: {_, _field, {_, value}}}) do
    options = values |> Enum.map(&Phoenix.Naming.humanize/1) |> Enum.zip(values)

    [
      select(form, field, options, value: value, class: Field.default_style(:select))
    ]
  end

  defp inputs(form, field, %{type: :string, _filter: {_op, _field, {op, val}}}) do
    options = [contains: :contains, not: :not]

    [
      select(form, field, options,
        name: "#{field}[operator]",
        value: atom_to_operator(op),
        class: ["mr-2 " | Field.default_style(:select)]
      ),
      text_input(form, field,
        name: "#{field}[value]",
        value: val,
        phx_debounce: @default_debounce,
        class: Field.default_style(:string)
      )
    ]
  end

  defp inputs(form, field, %{type: :boolean, _filter: {_op, _field, {_, val}}}) do
    checkbox(form, field, value: val, class: Field.default_style(:boolean))
  end

  defp inputs(form, field, %{type: :id, _filter: {_op, _field, {op, val}}}) do
    options = [contains: :contains, not: :not]

    [
      select(form, field, options,
        name: "#{field}[operator]",
        value: atom_to_operator(op),
        class: ["mr-2 " | Field.default_style(:select)]
      ),
      text_input(form, field,
        name: "#{field}[value]",
        value: val,
        phx_debounce: @default_debounce,
        class: Field.default_style(:string)
      )
    ]
  end

  defp inputs(form, field, %{type: type, _filter: {_op, _field, {_, datetime}}})
       when type in @datetime_fields do
    date = NaiveDateTime.to_date(datetime)

    [
      build_datetime_input(form, field, :from, Date.add(date, -7)),
      build_datetime_input(form, field, :to, date)
    ]
  end

  defp inputs(_, _, %{type: type}),
    do:
      {:safe,
       ~s(<p class="text-sm text-gray-400">Filter by #{inspect(type)} is not supported yet</p>)}

  defp build_datetime_input(form, field, type, value) do
    [
      {:safe, ~s(<div class="mt-1 flex rounded-md shadow-sm">
            <span class="inline-flex items-center px-3 rounded-l-md border border-r-0 border-gray-300 bg-gray-50 text-gray-500 sm:text-sm">
              #{Phoenix.Naming.humanize(type)}
            </span>)},
      text_input(form, field,
        name: "#{field}[#{type}]",
        value: to_string(value),
        phx_debounce: @default_debounce,
        class: ["mr-2 " | Field.default_style(:datetime)]
      ),
      {:safe, ~s(</div>)}
    ]
  end

  defp default_value(%{type: :boolean}), do: true
  defp default_value(%{type: :id}), do: 0
  defp default_value(%{type: Ecto.Enum, values: [head | _]}), do: head

  defp default_value(%{type: type}) when type in @datetime_fields do
    to = Date.utc_today()
    from = Date.add(to, -7)

    %{
      "from" => to_string(from),
      "to" => to_string(to)
    }
  end

  defp default_value(_), do: ""

  defp name(string), do: Phoenix.Naming.humanize(string)

  # TODO: Refactor contains to use substring "~" and reserve this to use equality match.
  defp operator_to_string("contains"), do: ""
  defp operator_to_string("not"), do: "[not]"

  defp atom_to_operator(:contains), do: "contains"
  defp atom_to_operator(:not), do: "not"
end
