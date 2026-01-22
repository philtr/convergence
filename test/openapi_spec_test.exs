defmodule Convergence.OpenApiSpecTest do
  use ExUnit.Case, async: true

  test "openapi spec exists and defines room endpoints" do
    spec =
      "openapi.json"
      |> File.read!()
      |> Jason.decode!()

    assert spec["openapi"] == "3.0.3"
    assert spec["info"]["title"] == "Convergence Sync API"

    assert Map.has_key?(spec["paths"], "/api/rooms/{room_id}")
  end
end
