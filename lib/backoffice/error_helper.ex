defmodule Backoffice.ErrorHelper do
  use Phoenix.HTML

  def error_tag(form, field) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.map(fn error ->
      content_tag(:span, translate_error(error),
        class: "invalid-feedback text-xs text-red-500",
        phx_feedback_for: input_name(form, field)
      )
    end)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, msg ->
      token = "%{#{key}}"

      case String.contains?(msg, token) do
        true -> String.replace(msg, token, to_string(value), global: false)
        false -> msg
      end
    end)
  end
end
