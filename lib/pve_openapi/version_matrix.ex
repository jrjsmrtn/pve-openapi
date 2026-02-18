# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.VersionMatrix do
  @moduledoc """
  Query endpoint availability across PVE versions.

  Built at compile time from the loaded specs.

  ## Usage

      PveOpenapi.VersionMatrix.endpoint_available?("/nodes/{node}/qemu", :get, "8.3")
      #=> true

      PveOpenapi.VersionMatrix.endpoint_added_in("/cluster/ha/affinity", :get)
      #=> "9.0"

      PveOpenapi.VersionMatrix.endpoints_for_version("8.3")
      #=> MapSet of {path, method} tuples
  """

  alias PveOpenapi.Spec

  # Build the matrix at compile time
  @matrix (
            versions = PveOpenapi.versions()

            for version <- versions, into: %{} do
              spec = PveOpenapi.spec!(version)
              {version, Spec.endpoint_set(spec)}
            end
          )

  @all_endpoints @matrix
                 |> Map.values()
                 |> Enum.reduce(MapSet.new(), &MapSet.union/2)

  # Module attributes inline MapSet structs, exposing opaque internals to dialyzer
  @dialyzer {:no_opaque, all_endpoints: 0, endpoints_for_version: 1}

  @doc """
  Check if an endpoint exists in a specific PVE version.
  """
  @spec endpoint_available?(String.t(), atom(), String.t()) :: boolean()
  def endpoint_available?(path, method, version) do
    case Map.fetch(@matrix, version) do
      {:ok, endpoints} -> MapSet.member?(endpoints, {path, method})
      :error -> false
    end
  end

  @doc """
  Find the earliest version where an endpoint was added.

  Returns the version string or `nil` if not found in any version.
  """
  @spec endpoint_added_in(String.t(), atom()) :: String.t() | nil
  def endpoint_added_in(path, method) do
    PveOpenapi.versions()
    |> Enum.find(fn version ->
      endpoint_available?(path, method, version)
    end)
  end

  @doc """
  Find the last version where an endpoint was present before being removed.

  Returns `nil` if the endpoint still exists in the latest version or was never present.
  """
  @spec endpoint_removed_in(String.t(), atom()) :: String.t() | nil
  def endpoint_removed_in(path, method) do
    versions = PveOpenapi.versions()

    with added when not is_nil(added) <- endpoint_added_in(path, method),
         false <- endpoint_available?(path, method, List.last(versions)) do
      find_removal_version(versions, path, method)
    else
      nil -> nil
      true -> nil
    end
  end

  defp find_removal_version(versions, path, method) do
    versions
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn [prev, next] ->
      if endpoint_available?(path, method, prev) and
           not endpoint_available?(path, method, next) do
        next
      end
    end)
  end

  @doc """
  Return the set of {path, method} tuples available in a version.
  """
  @spec endpoints_for_version(String.t()) :: MapSet.t()
  def endpoints_for_version(version) do
    Map.get(@matrix, version, MapSet.new())
  end

  @doc """
  Return all endpoints that appear in any version.
  """
  @spec all_endpoints() :: MapSet.t()
  def all_endpoints, do: @all_endpoints

  @doc """
  Return a list of versions where the endpoint is available.
  """
  @spec versions_for_endpoint(String.t(), atom()) :: [String.t()]
  def versions_for_endpoint(path, method) do
    PveOpenapi.versions()
    |> Enum.filter(&endpoint_available?(path, method, &1))
  end
end
