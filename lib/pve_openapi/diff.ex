# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.Diff do
  @moduledoc """
  Compute diffs between PVE API versions.

  ## Usage

      PveOpenapi.Diff.added_endpoints("8.3", "9.0")
      #=> [{"/cluster/ha/affinity", :get}, ...]

      PveOpenapi.Diff.removed_endpoints("7.0", "7.1")
      #=> []

      PveOpenapi.Diff.summary("8.3", "9.0")
      #=> %{added: 30, removed: 0, ...}
  """

  alias PveOpenapi.{Spec, VersionMatrix}

  @type endpoint_ref :: {String.t(), atom()}

  @doc """
  Return endpoints added between `from_version` and `to_version`.
  """
  @spec added_endpoints(String.t(), String.t()) :: [endpoint_ref()]
  def added_endpoints(from_version, to_version) do
    from_set = VersionMatrix.endpoints_for_version(from_version)
    to_set = VersionMatrix.endpoints_for_version(to_version)

    MapSet.difference(to_set, from_set)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Return endpoints removed between `from_version` and `to_version`.
  """
  @spec removed_endpoints(String.t(), String.t()) :: [endpoint_ref()]
  def removed_endpoints(from_version, to_version) do
    from_set = VersionMatrix.endpoints_for_version(from_version)
    to_set = VersionMatrix.endpoints_for_version(to_version)

    MapSet.difference(from_set, to_set)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Return endpoints present in both versions (may have parameter changes).
  """
  @spec common_endpoints(String.t(), String.t()) :: [endpoint_ref()]
  def common_endpoints(from_version, to_version) do
    from_set = VersionMatrix.endpoints_for_version(from_version)
    to_set = VersionMatrix.endpoints_for_version(to_version)

    MapSet.intersection(from_set, to_set)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Detect breaking changes: removed endpoints and removed required parameters.
  """
  @spec breaking_changes(String.t(), String.t()) :: [map()]
  def breaking_changes(from_version, to_version) do
    removed =
      removed_endpoints(from_version, to_version)
      |> Enum.map(fn {path, method} ->
        %{type: :endpoint_removed, path: path, method: method}
      end)

    param_changes =
      common_endpoints(from_version, to_version)
      |> Enum.flat_map(fn {path, method} ->
        detect_param_breaking_changes(from_version, to_version, path, method)
      end)

    (removed ++ param_changes) |> Enum.sort_by(&{&1.path, &1[:method]})
  end

  @doc """
  Return a summary of differences between two versions.
  """
  @spec summary(String.t(), String.t()) :: map()
  def summary(from_version, to_version) do
    added = added_endpoints(from_version, to_version)
    removed = removed_endpoints(from_version, to_version)
    common = common_endpoints(from_version, to_version)
    breaking = breaking_changes(from_version, to_version)

    %{
      from: from_version,
      to: to_version,
      added: length(added),
      removed: length(removed),
      common: length(common),
      breaking: length(breaking)
    }
  end

  defp detect_param_breaking_changes(from_version, to_version, path, method) do
    from_spec = PveOpenapi.spec!(from_version)
    to_spec = PveOpenapi.spec!(to_version)

    with {:ok, from_op} <- Spec.operation(from_spec, path, method),
         {:ok, to_op} <- Spec.operation(to_spec, path, method) do
      from_params = extract_required_params(from_op)
      to_params = extract_required_params(to_op)

      # New required parameters are breaking
      new_required = MapSet.difference(to_params, from_params)

      new_required
      |> Enum.map(fn param ->
        %{
          type: :new_required_parameter,
          path: path,
          method: method,
          parameter: param
        }
      end)
    else
      _ -> []
    end
  end

  defp extract_required_params(operation) do
    params =
      (operation["parameters"] || [])
      |> Enum.filter(&(&1["required"] == true))
      |> Enum.map(& &1["name"])

    body_required =
      case operation["requestBody"] do
        %{"content" => %{"application/json" => %{"schema" => %{"required" => req}}}}
        when is_list(req) ->
          req

        _ ->
          []
      end

    MapSet.new(params ++ body_required)
  end
end
