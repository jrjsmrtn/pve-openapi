# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.Endpoint do
  @moduledoc """
  Represents a single API endpoint (path + method) from a PVE OpenAPI spec.
  """

  @type t :: %__MODULE__{
          path: String.t(),
          method: atom(),
          operation_id: String.t(),
          summary: String.t(),
          description: String.t(),
          tags: [String.t()],
          parameters: [map()],
          request_body: map() | nil,
          responses: map(),
          extensions: map()
        }

  defstruct [
    :path,
    :method,
    :operation_id,
    :summary,
    :description,
    tags: [],
    parameters: [],
    request_body: nil,
    responses: %{},
    extensions: %{}
  ]

  @methods [:get, :post, :put, :delete]

  @doc """
  Build an Endpoint struct from a path string, HTTP method atom, and OpenAPI operation map.
  """
  @spec from_operation(String.t(), atom(), map()) :: t()
  def from_operation(path, method, operation) when method in @methods do
    extensions =
      operation
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "x-") end)
      |> Map.new()

    %__MODULE__{
      path: path,
      method: method,
      operation_id: operation["operationId"] || "",
      summary: operation["summary"] || "",
      description: operation["description"] || "",
      tags: operation["tags"] || [],
      parameters: operation["parameters"] || [],
      request_body: operation["requestBody"],
      responses: operation["responses"] || %{},
      extensions: extensions
    }
  end
end
