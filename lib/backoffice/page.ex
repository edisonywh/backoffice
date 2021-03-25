defmodule Backoffice.Page do
  @type t :: %{
          entries: [term()],
          page_number: integer(),
          page_size: integer(),
          total_entries: integer(),
          total_pages: integer()
        }

  defstruct entries: [],
            page_number: 0,
            page_size: 0,
            total_entries: 0,
            total_pages: 0
end
