defmodule Backoffice.Layout do
  @type link :: %{optional(:icon) => nil | String.t(), link: String.t(), label: String.t()}

  @callback links() :: [link()]
end
