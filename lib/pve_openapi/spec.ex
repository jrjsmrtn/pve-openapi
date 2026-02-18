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

  defp method_order(:get), do: 0
  defp method_order(:post), do: 1
  defp method_order(:put), do: 2
  defp method_order(:delete), do: 3
end
