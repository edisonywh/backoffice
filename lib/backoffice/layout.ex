defmodule Backoffice.Layout do
  @type link :: %{optional(:icon) => nil | String.t(), link: String.t(), label: String.t()}

  @callback links() :: [link()]
  @callback logo() :: String.t()
  @callback stylesheets() :: [String.t()]
  @callback scripts() :: [String.t()]
  @callback static_path() :: String.t()
end
