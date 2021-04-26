ExUnit.start()

import Mox

defmodule Backoffice.RepoMockBehaviour do
  @callback all(Ecto.Queryable.t()) :: [Ecto.Schema.t()]
  @callback one(Ecto.Queryable.t()) :: integer() | Ecto.Schema.t()
end

defmock(RepoMock, for: Backoffice.RepoMockBehaviour)
