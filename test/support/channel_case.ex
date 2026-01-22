defmodule ConvergenceWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require testing channels.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest

      @endpoint ConvergenceWeb.Endpoint
    end
  end
end
