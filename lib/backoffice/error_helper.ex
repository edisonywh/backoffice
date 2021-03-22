defmodule Backoffice.ErrorHelper do
  use Phoenix.HTML

  def error_tag(form, field, opts \\ []) do
    class = Keyword.get(opts, :class, "")

    Enum.map(Keyword.get_values(form.errors, field), fn {error, _} ->
      content_tag(:span, error,
        class: "text-xs text-red-500 " <> class,
        data: [phx_error_for: input_id(form, field)]
      )
    end)
  end
end
