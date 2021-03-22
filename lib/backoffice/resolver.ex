defmodule Backoffice.Resolver do
  @callback load(module(), keyword(), map()) :: term()
  @callback get(module(), keyword(), map()) :: term()
  @callback change(keyword(), map(), map()) :: Ecto.Changeset.t()
  @callback save(keyword(), Ecto.Changeset.t()) :: {:ok, term()} | {:error, term()}
end
