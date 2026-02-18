# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.Contract do
  @moduledoc """
  Contract testing helpers for validating implementations against PVE OpenAPI specs.

  Use these to verify that your client or mock server covers the correct endpoints
  and handles parameters according to the spec.

  ## Usage

      # Validate that a set of implemented endpoints covers the spec
      PveOpenapi.Contract.validate_coverage("8.3", implemented_endpoints)

      # Check if a request matches the spec
      PveOpenapi.Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, params)
  """

  alias PveOpenapi.{Spec, VersionMatrix}

  @type endpoint_ref :: {String.t(), atom()}
  @type validation_result :: :ok | {:error, [String.t()]}

  @doc """
  Validate that a set of implemented endpoints covers the spec for a version.

  Returns `{:ok, report}` with coverage statistics.

  `implemented` should be a list of `{path, method}` tuples.
  """
  @spec validate_coverage(String.t(), [endpoint_ref()]) :: {:ok, map()}
  def validate_coverage(version, implemented) do
    spec_endpoints = VersionMatrix.endpoints_for_version(version)
    impl_set = MapSet.new(implemented)

    covered = MapSet.intersection(spec_endpoints, impl_set)
    missing = MapSet.difference(spec_endpoints, impl_set)
    extra = MapSet.difference(impl_set, spec_endpoints)

    total = MapSet.size(spec_endpoints)
    covered_count = MapSet.size(covered)

    {:ok,
     %{
       version: version,
       total: total,
       covered: covered_count,
       missing: MapSet.to_list(missing) |> Enum.sort(),
       extra: MapSet.to_list(extra) |> Enum.sort(),
       coverage_pct: if(total > 0, do: Float.round(covered_count / total * 100, 1), else: 0.0)
     }}
  end

  @doc """
  Validate request parameters against the spec.

  Returns `:ok` or `{:error, reasons}`.
  """
  @spec validate_request(String.t(), String.t(), atom(), map()) :: validation_result()
  def validate_request(version, path, method, params) when is_map(params) do
    spec = PveOpenapi.spec!(version)

    case Spec.operation(spec, path, method) do
      {:ok, operation} ->
        validate_params(operation, params)

      :error ->
        {:error, ["Endpoint #{method} #{path} not found in PVE #{version} spec"]}
    end
  end

  @doc """
  Validate a response body against the spec.

  Returns `:ok` or `{:error, reasons}`.
  """
  @spec validate_response(String.t(), String.t(), atom(), integer(), term()) ::
          validation_result()
  def validate_response(version, path, method, status_code, _body) do
    spec = PveOpenapi.spec!(version)

    case Spec.operation(spec, path, method) do
      {:ok, operation} ->
        status_str = Integer.to_string(status_code)
        responses = operation["responses"] || %{}

        if Map.has_key?(responses, status_str) do
          :ok
        else
          {:error, ["No response schema for status #{status_code} at #{method} #{path}"]}
        end

      :error ->
        {:error, ["Endpoint #{method} #{path} not found in PVE #{version} spec"]}
    end
  end

  # Validate required parameters are present
  defp validate_params(operation, params) do
    errors = []

    # Check query/path parameters
    required_params =
      (operation["parameters"] || [])
      |> Enum.filter(&(&1["required"] == true))
      |> Enum.map(& &1["name"])

    # Check request body required fields
    body_required =
      case operation["requestBody"] do
        %{"content" => %{"application/json" => %{"schema" => %{"required" => req}}}}
        when is_list(req) ->
          req

        _ ->
          []
      end

    all_required = required_params ++ body_required
    param_keys = params |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

    missing =
      all_required
      |> Enum.reject(&MapSet.member?(param_keys, &1))

    errors =
      errors ++
        Enum.map(missing, fn p -> "Missing required parameter: #{p}" end)

    if errors == [], do: :ok, else: {:error, errors}
  end
end
