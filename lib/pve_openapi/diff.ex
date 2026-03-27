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

      PveOpenapi.Diff.parameter_changes("8.3", "8.4")
      #=> [%{path: "/nodes/{node}/qemu/{vmid}/config", method: :put, changes: [...]}]

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
  Detect parameter-level changes for common endpoints between two versions.

  Returns a list of maps, one per endpoint that has changes:

      %{
        path: "/nodes/{node}/qemu/{vmid}/config",
        method: :put,
        changes: [
          %{type: :param_added, name: "new_param", required: false},
          %{type: :param_removed, name: "old_param"},
          %{type: :type_changed, name: "vmid", from: "string", to: "integer"},
          %{type: :became_required, name: "memory"},
          %{type: :constraint_changed, name: "cpu", field: "maximum", from: 128, to: 256}
        ]
      }
  """
  @spec parameter_changes(String.t(), String.t()) :: [map()]
  def parameter_changes(from_version, to_version) do
    from_spec = PveOpenapi.spec!(from_version)
    to_spec = PveOpenapi.spec!(to_version)

    common_endpoints(from_version, to_version)
    |> Enum.map(fn {path, method} ->
      changes = compute_param_changes(from_spec, to_spec, path, method)
      {path, method, changes}
    end)
    |> Enum.reject(fn {_path, _method, changes} -> changes == [] end)
    |> Enum.map(fn {path, method, changes} ->
      %{path: path, method: method, changes: changes}
    end)
  end

  @doc """
  Return a complete structured diff suitable for JSON serialization.
  """
  @spec full_diff(String.t(), String.t()) :: map()
  def full_diff(from_version, to_version) do
    added = added_endpoints(from_version, to_version)
    removed = removed_endpoints(from_version, to_version)
    param_changes = parameter_changes(from_version, to_version)
    breaking = breaking_changes(from_version, to_version)

    %{
      from: from_version,
      to: to_version,
      added_endpoints: Enum.map(added, fn {p, m} -> %{path: p, method: m} end),
      removed_endpoints: Enum.map(removed, fn {p, m} -> %{path: p, method: m} end),
      parameter_changes: param_changes,
      breaking_changes: breaking,
      summary: %{
        added: length(added),
        removed: length(removed),
        parameter_changes: length(param_changes),
        breaking: length(breaking)
      }
    }
  end

  @doc """
  Detect breaking changes: removed endpoints, new required parameters,
  removed parameters, and type-incompatible changes.
  """
  @spec breaking_changes(String.t(), String.t()) :: [map()]
  def breaking_changes(from_version, to_version) do
    removed =
      removed_endpoints(from_version, to_version)
      |> Enum.map(fn {path, method} ->
        %{type: :endpoint_removed, path: path, method: method}
      end)

    param_breaking =
      parameter_changes(from_version, to_version)
      |> Enum.flat_map(fn %{path: path, method: method, changes: changes} ->
        changes
        |> Enum.filter(&breaking_param_change?/1)
        |> Enum.map(fn change ->
          %{
            type: change.type,
            path: path,
            method: method,
            parameter: change.name
          }
        end)
      end)

    (removed ++ param_breaking) |> Enum.sort_by(&{&1.path, &1[:method]})
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

  # --- Parameter diffing internals ---

  defp compute_param_changes(from_spec, to_spec, path, method) do
    with {:ok, from_op} <- Spec.operation(from_spec, path, method),
         {:ok, to_op} <- Spec.operation(to_spec, path, method) do
      from_params = extract_all_params(from_op)
      to_params = extract_all_params(to_op)

      from_names = Map.keys(from_params) |> MapSet.new()
      to_names = Map.keys(to_params) |> MapSet.new()

      added =
        MapSet.difference(to_names, from_names)
        |> Enum.map(fn name ->
          param = to_params[name]
          %{type: :param_added, name: name, required: param[:required] || false}
        end)

      removed =
        MapSet.difference(from_names, to_names)
        |> Enum.map(fn name -> %{type: :param_removed, name: name} end)

      changed =
        MapSet.intersection(from_names, to_names)
        |> Enum.flat_map(fn name ->
          diff_param(name, from_params[name], to_params[name])
        end)

      Enum.sort_by(added ++ removed ++ changed, & &1.name)
    else
      _ -> []
    end
  end

  defp extract_all_params(operation) do
    query_path_params =
      (operation["parameters"] || [])
      |> Enum.map(fn p ->
        {p["name"],
         %{
           type: get_in(p, ["schema", "type"]),
           required: p["required"] || false,
           schema: p["schema"] || %{}
         }}
      end)

    body_params =
      case get_in(operation, ["requestBody", "content"]) do
        %{"application/json" => %{"schema" => schema}} ->
          extract_body_params(schema)

        %{"application/x-www-form-urlencoded" => %{"schema" => schema}} ->
          extract_body_params(schema)

        _ ->
          []
      end

    Map.new(query_path_params ++ body_params)
  end

  defp extract_body_params(%{"properties" => props} = schema) when is_map(props) do
    required_set = MapSet.new(schema["required"] || [])

    Enum.map(props, fn {name, prop_schema} ->
      {name,
       %{
         type: prop_schema["type"],
         required: MapSet.member?(required_set, name),
         schema: prop_schema
       }}
    end)
  end

  defp extract_body_params(_), do: []

  defp diff_param(name, from, to) do
    changes = []

    changes =
      if from.type != to.type do
        [%{type: :type_changed, name: name, from: from.type, to: to.type} | changes]
      else
        changes
      end

    changes =
      if !from.required && to.required do
        [%{type: :became_required, name: name} | changes]
      else
        changes
      end

    changes = changes ++ diff_constraints(name, from.schema, to.schema)

    changes
  end

  @constraint_fields ~w(minimum maximum minLength maxLength pattern enum)

  defp diff_constraints(name, from_schema, to_schema) do
    @constraint_fields
    |> Enum.flat_map(fn field ->
      from_val = from_schema[field]
      to_val = to_schema[field]

      if from_val != to_val && (from_val != nil || to_val != nil) do
        [%{type: :constraint_changed, name: name, field: field, from: from_val, to: to_val}]
      else
        []
      end
    end)
  end

  defp breaking_param_change?(%{type: :param_removed}), do: true
  defp breaking_param_change?(%{type: :became_required}), do: true
  defp breaking_param_change?(%{type: :type_changed}), do: true
  defp breaking_param_change?(_), do: false
end
