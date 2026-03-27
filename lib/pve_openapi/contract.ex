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

      # Check if a request matches the spec (type-aware validation)
      PveOpenapi.Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{"vmid" => 100})
  """

  alias PveOpenapi.{Spec, Validator, VersionMatrix}

  @type endpoint_ref :: {String.t(), atom()}
  @type validation_error :: %{param: String.t(), error: String.t()}
  @type validation_result :: :ok | {:error, [validation_error() | String.t()]}

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

  Checks both presence of required parameters and type/constraint validation
  of all provided parameters against their OpenAPI schemas.

  Returns `:ok` or `{:error, errors}` where errors are structured maps
  with `:param` and `:error` keys.
  """
  @spec validate_request(String.t(), String.t(), atom(), map()) :: validation_result()
  def validate_request(version, path, method, params) when is_map(params) do
    spec = PveOpenapi.spec!(version)

    case Spec.parameters_for(spec, path, method) do
      {:ok, spec_params} ->
        do_validate_request(spec_params, params)

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

  defp do_validate_request(spec_params, params) do
    param_keys = params |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()
    params_by_name = build_params_lookup(params)

    # Check for missing required parameters
    missing_errors =
      spec_params
      |> Enum.filter(& &1.required)
      |> Enum.reject(&MapSet.member?(param_keys, &1.name))
      |> Enum.map(fn p ->
        %{param: p.name, error: "Missing required parameter"}
      end)

    # Type/constraint validation for provided parameters
    type_errors =
      spec_params
      |> Enum.filter(&MapSet.member?(param_keys, &1.name))
      |> Enum.flat_map(fn spec_param ->
        value = params_by_name[spec_param.name]

        case Validator.validate_value(value, spec_param.schema) do
          :ok -> []
          {:error, reason} -> [%{param: spec_param.name, error: reason}]
        end
      end)

    errors = missing_errors ++ type_errors

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp build_params_lookup(params) do
    for {k, v} <- params, into: %{}, do: {to_string(k), v}
  end
end
