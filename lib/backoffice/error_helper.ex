defmodule Backoffice.ErrorHelper do
  use Phoenix.HTML

  def traverse_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&translate_error/1)
    |> format_errors()
  end

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

      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join(", ")
  end
end
