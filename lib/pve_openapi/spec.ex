# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.Spec do
  @moduledoc """
  Functions for querying a single OpenAPI spec.
  """

  alias PveOpenapi.Endpoint

  @http_methods ~w(get post put delete)

  @doc """
  Extract all endpoints from a parsed OpenAPI spec as Endpoint structs.
  """
  @spec endpoints(map()) :: [Endpoint.t()]
  def endpoints(%{"paths" => paths}) do
    for {path, methods} <- paths,
        {method_str, operation} <- methods,
        method_str in @http_methods do
      Endpoint.from_operation(path, String.to_existing_atom(method_str), operation)
    end
    |> Enum.sort_by(&{&1.path, method_order(&1.method)})
  end

  def endpoints(_), do: []

  @doc """
  Return the set of {path, method} tuples in the spec.
  """
  @spec endpoint_set(map()) :: MapSet.t({String.t(), atom()})
  def endpoint_set(spec) do
    spec
    |> endpoints()
    |> Enum.map(&{&1.path, &1.method})
    |> MapSet.new()
  end

  @doc """
  Count paths and operations in a spec.
  """
  @spec stats(map()) :: %{paths: non_neg_integer(), operations: non_neg_integer()}
  def stats(%{"paths" => paths}) do
    operations =
      paths
      |> Enum.flat_map(fn {_path, methods} ->
        Enum.filter(methods, fn {m, _} -> m in @http_methods end)
      end)
      |> length()

    %{paths: map_size(paths), operations: operations}
  end

  def stats(_), do: %{paths: 0, operations: 0}

  @doc """
  Look up a specific operation by path and method.
  """
  @spec operation(map(), String.t(), atom()) :: {:ok, map()} | :error
  def operation(%{"paths" => paths}, path, method) when is_atom(method) do
    case Map.fetch(paths, path) do
      {:ok, methods} -> Map.fetch(methods, Atom.to_string(method))
      :error -> :error
    end
  end

  def operation(_, _, _), do: :error

  @doc """
  Return structured parameter information for an operation.

  Each parameter includes `:name`, `:type`, `:required`, `:in` (path/query/body),
  and `:schema` (the raw OpenAPI schema).
  """
  @spec parameters_for(map(), String.t(), atom()) :: {:ok, [map()]} | :error
  def parameters_for(spec, path, method) do
    case operation(spec, path, method) do
      {:ok, op} -> {:ok, extract_parameters(op)}
      :error -> :error
    end
  end

  @doc """
  Return the response schema for a given status code.
  """
  @spec response_schema(map(), String.t(), atom(), integer()) :: {:ok, map()} | :error
  def response_schema(spec, path, method, status_code) do
    with {:ok, op} <- operation(spec, path, method),
         status_str = Integer.to_string(status_code),
         {:ok, response} <- Map.fetch(op["responses"] || %{}, status_str) do
      schema =
        get_in(response, ["content", "application/json", "schema"]) ||
          response["schema"] ||
          %{}

      {:ok, schema}
    else
      _ -> :error
    end
  end

  @doc """
  Return the list of required parameter names for an operation.
  """
  @spec required_parameters(map(), String.t(), atom()) :: {:ok, [String.t()]} | :error
  def required_parameters(spec, path, method) do
    case parameters_for(spec, path, method) do
      {:ok, params} ->
        required = params |> Enum.filter(& &1.required) |> Enum.map(& &1.name)
        {:ok, required}

      :error ->
        :error
    end
  end

  # --- Internals ---

  defp extract_parameters(operation) do
    query_path_params =
      (operation["parameters"] || [])
      |> Enum.map(fn p ->
        %{
          name: p["name"],
          type: get_in(p, ["schema", "type"]),
          required: p["required"] || false,
          in: p["in"],
          schema: p["schema"] || %{}
        }
      end)

    body_params = extract_body_parameters(operation)

    Enum.sort_by(query_path_params ++ body_params, & &1.name)
  end

  defp extract_body_parameters(operation) do
    schema =
      get_in(operation, ["requestBody", "content", "application/json", "schema"]) ||
        get_in(operation, [
          "requestBody",
          "content",
          "application/x-www-form-urlencoded",
          "schema"
        ])

    case schema do
      %{"properties" => props} when is_map(props) ->
        required_set = MapSet.new(schema["required"] || [])

        Enum.map(props, fn {name, prop_schema} ->
          %{
            name: name,
            type: prop_schema["type"],
            required: MapSet.member?(required_set, name),
            in: "body",
            schema: prop_schema
          }
        end)

      _ ->
        []
    end
  end

  defp method_order(:get), do: 0
  defp method_order(:post), do: 1
  defp method_order(:put), do: 2
  defp method_order(:delete), do: 3
end
