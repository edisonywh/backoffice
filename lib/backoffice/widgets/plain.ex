defmodule Backoffice.PlainWidget do
  defstruct [:title, :data, :hint, :subtitle]

  defimpl Backoffice.Widget do
    def render(widget) do
      [
        {:safe, ~s(<div class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6">)},
        {:safe, ~s(<dt class="text-sm font-medium text-gray-500 truncate">)},
        {:safe, to_string(widget.title)},
        {:safe, ~s(</dt>)},
        {:safe, ~s(<dd class="mt-1 text-3xl font-semibold text-gray-900">)},
        {:safe, to_string(widget.data)},
        {:safe, ~s(</dd>)},
        {:safe, ~s(<dd class="mt-1 text-xs text-gray-400">)},
        {:safe, to_string(widget.subtitle)},
        {:safe, ~s(</dd>)},
        {:safe, ~s(</div>)}
      ]
    end
  end
end
