defmodule Backoffice.SearchComponent do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~L"""
    <div class="justify-between flex flex-row content-center mt-4">
      <div class="max-w-xs">
        <div class="relative rounded-md shadow-sm">
          <form phx-submit="search">
            <input type="text" name="search" value="<%= @search %>" placeholder="Search.." class="block w-full border-gray-300 rounded-md focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50 sm:text-sm sm:leading-5"/>
            <button type="submit" class="absolute inset-y-0 right-0 px-3 flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
