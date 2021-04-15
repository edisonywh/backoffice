defmodule Backoffice.LiveView.Helpers do
  @doc """
  Helper to push a notification to Backoffice.

  You can pass in `:level` for it to render different icon such as `:success`, `:error` and `:info` (default)

  There are two prerequisite for this to work:

  1) The actual notification pop-up (included in layout)
  2) A DOM element with `phx-hook='Notification'` (included)

  If you want to use it in your own custom pages, just do:

  <%= render Backoffice.ResourceView, "_notification.html" %>

  Note:

  `push_event/3` doesn't work with `push_redirect/3` because events are only dispatched on JS's side after patch.

  As a workaround, Backoffice provides a callback to handle redirect for you.

  ```elixir
  push_notification(socket, title: "Success", subtitle: "Subtitle", redirect: socket.assigns.return_to)
  ```
  """
  defmacro push_notification(socket, opts) do
    quote bind_quoted: [socket: socket, opts: opts] do
      level = Keyword.get(opts, :level, :info)
      title = Keyword.fetch!(opts, :title)
      subtitle = Keyword.fetch!(opts, :subtitle)
      redirect = Keyword.get(opts, :redirect)

      push_event(socket, "bo-notification", %{
        level: level,
        title: title,
        subtitle: subtitle,
        redirect: redirect
      })
    end
  end
end
