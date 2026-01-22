defmodule ConvergenceWeb.RoomStreamControllerTest do
  use ConvergenceWeb.ConnCase, async: true

  defp room_id do
    "room-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  setup do
    {:ok, pid} =
      start_supervised(
        {Bandit, plug: ConvergenceWeb.Endpoint, scheme: :http, ip: {127, 0, 0, 1}, port: 0}
      )

    {:ok, {{127, 0, 0, 1}, port}} = ThousandIsland.listener_info(pid)
    {:ok, base_url: "http://127.0.0.1:#{port}"}
  end

  test "stream emits current state then updates", %{base_url: base_url} do
    room_id = room_id()
    resp = Req.get!(base_url <> "/api/rooms/#{room_id}/stream", into: :self)

    assert resp.status == 200
    assert ["text/event-stream" <> _] = Map.fetch!(resp.headers, "content-type")

    async = resp.body
    first = recv_event(async.ref)

    assert first["version"] == 0
    assert first["state"] == nil

    state = %{"foo" => "bar"}
    put_resp = Req.put!(base_url <> "/api/rooms/#{room_id}", json: %{state: state})

    assert put_resp.status == 200

    next = recv_event(async.ref)

    assert next["version"] == 1
    assert next["state"] == state

    async.cancel_fun.(async.ref)

    _ =
      Req.put!(base_url <> "/api/rooms/#{room_id}",
        json: %{
          state: %{"foo" => "baz"}
        }
      )
  end

  defp recv_event(ref, acc \\ "") do
    {block, rest} = recv_block(ref, acc)

    case parse_event(block) do
      {:ok, event} -> event
      :skip -> recv_event(ref, rest)
    end
  end

  defp recv_block(ref, acc) do
    receive do
      {^ref, {:data, chunk}} ->
        acc = acc <> chunk

        case String.split(acc, "\n\n", parts: 2) do
          [block, rest] -> {block, rest}
          [_] -> recv_block(ref, acc)
        end
    after
      1_000 ->
        flunk("timed out waiting for SSE event")
    end
  end

  defp parse_event(block) do
    data_line =
      block
      |> String.split("\n", trim: true)
      |> Enum.find_value(fn line ->
        if String.starts_with?(line, "data:") do
          line
          |> String.trim_leading("data:")
          |> String.trim()
        end
      end)

    if data_line do
      {:ok, Jason.decode!(data_line)}
    else
      :skip
    end
  end
end
