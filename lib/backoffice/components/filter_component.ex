defmodule Backoffice.FilterComponent do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:add, false)
      |> assign(:filter, "")
      |> assign(:value, "")

    {:ok, socket}
  end

  @impl true
  def update(%{params: params}, socket) do
    filters =
      params
      |> Enum.map(&Backoffice.Filter.preprocess/1)
      |> List.flatten()

    {:ok, assign(socket, :filters, filters)}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= for {_and, field, {op, value}} <- @filters do %>
      <span class="inline-flex rounded-full mr-2 mt-1.5 items-center py-1 pl-2.5 pr-1 text-sm bg-gray-100 text-gray-700">
        <p class="text-black"><%= name(field) %></p>
        <p class="text-gray-400 px-1.5"> <%= op(op) %> </p>
        <p class="text-black"><%= value(value) %></p>
        <button phx-target="<%= @myself %>" phx-click="remove" phx-value-filter="<%= field %>" type="button" class="flex-shrink-0 ml-2 h-4 w-4 rounded-full inline-flex items-center justify-center text-gray-400 hover:bg-gray-200 hover:text-gray-500 focus:outline-none focus:bg-gray-500 focus:text-white">
          <span class="sr-only">Remove <%= field %></span>
          <svg class="h-2 w-2" stroke="currentColor" fill="none" viewBox="0 0 8 8">
            <path stroke-linecap="round" stroke-width="1.5" d="M1 1l6 6m0-6L1 7" />
          </svg>
        </button>
      </span>
    <% end %>
    <span phx-target="<%= @myself %>" phx-click="add" class="cursor-pointer inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
      <svg class="h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      </svg>
      <p class="ml-0.5">Filter</p>
    </span>
    <%= if @add do %>
      <form phx-submit="apply" phx-target="<%= @myself %>">
        <div class="bg-white absolute ml-4 p-4 rounded-md shadow-lg"">
          <div class="flex -space-x-px mb-4">
            <div class="w-1/3 flex-1 min-w-0">
              <label for="filter" class="sr-only">Filter Field</label>
              <input type="text" name="filter" id="filter" value="<%= @filter %>" class="focus:ring-indigo-500 focus:border-indigo-500 relative block w-full rounded-none rounded-bl-md rounded-tl-md bg-transparent focus:z-10 sm:text-sm border-gray-300" placeholder="Field">
            </div>
            <div class="flex-1 min-w-0">
              <label for="value" class="sr-only">Filter Value</label>
              <input type="text" name="value" id="value" value="<%= @value %>" class="focus:ring-indigo-500 focus:border-indigo-500 relative block w-full rounded-none rounded-br-md rounded-tr-md bg-transparent focus:z-10 sm:text-sm border-gray-300" placeholder="Value">
            </div>
          </div>
          <div class="flex justify-around">
            <button type="button" phx-target="<%= @myself %>" phx-click="cancel" class="inline-flex items-center justify-center w-6/12 px-3 py-2 bg-gray-50 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">Cancel</button>
            <button phx-target="<%= @myself %>" class="inline-flex items-center justify-center w-6/12 ml-3 px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">Apply</button>
          </div>
        </div>
      </form>
    <% end %>
    """
  end

  @impl true
  def handle_event("remove", %{"filter" => filter}, socket) do
    send(self(), {:remove_filter, filter})
    {:noreply, socket}
  end

  @impl true
  def handle_event("apply", %{"filter" => filter, "value" => value}, socket)
      when filter != "" and value != "" do
    send(self(), {:apply_filter, filter, value})
    {:noreply, socket}
  end

  @impl true
  def handle_event("apply", %{"filter" => _, "value" => _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add", _, socket) do
    {:noreply, assign(socket, :add, true)}
  end

  @impl true
  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, :add, false)}
  end

  defp name(string), do: Phoenix.Naming.humanize(string)

  defp op(:not), do: "not equal to"
  defp op(:contains), do: "contains"
  defp op(:desc), do: "descending"
  defp op(:asc), do: "ascending"
  defp op(:lt), do: "is less than"
  defp op(:lte), do: "is less than or equal to"
  defp op(:gt), do: "is greater than"
  defp op(:gte), do: "is greater than or equal to"

  defp value(nil), do: "nil"
  defp value(value), do: value
end
