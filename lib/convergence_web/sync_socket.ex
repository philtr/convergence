defmodule ConvergenceWeb.SyncSocket do
  use Phoenix.Socket

  channel "room:*", ConvergenceWeb.RoomChannel

  @impl Phoenix.Socket
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl Phoenix.Socket
  def id(_socket), do: nil
end
