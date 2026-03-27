# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi do
  @moduledoc """
  OpenAPI 3.1 specifications for the Proxmox VE REST API.

  Provides a single source of truth for PVE API endpoint definitions
  across versions 7.0 through 9.0. Specs are loaded at compile time
  from committed OpenAPI JSON files.

  ## Usage

      PveOpenapi.versions()
      #=> ["7.0", "7.1", ..., "9.0"]

      PveOpenapi.spec("8.3")
      #=> %{"openapi" => "3.1.0", "info" => ..., "paths" => ...}

      PveOpenapi.endpoints("8.3")
      #=> [%PveOpenapi.Endpoint{path: "/access", method: :get, ...}, ...]
  """

  alias PveOpenapi.Spec

  @specs_openapi_path Application.compile_env(
                        :pve_openapi,
                        :specs_path,
                        Path.join([__DIR__, "..", "specs", "openapi"]) |> Path.expand()
                      )
  @specs_base Path.dirname(@specs_openapi_path)
  @metadata_path Path.join(@specs_base, "metadata.json")

  @external_resource @metadata_path

  # Gracefully handle missing specs (they are generated artifacts)
  @metadata (if File.exists?(@metadata_path) do
               @metadata_path |> File.read!() |> Jason.decode!()
             else
               %{"versions" => []}
             end)

  @versions @metadata["versions"]
            |> Enum.map(& &1["version"])
            |> Enum.sort_by(fn v ->
              v |> String.split(".") |> Enum.map(&String.to_integer/1)
            end)

  # Compile-time loading of all specs
  @specs (for %{"version" => version, "file" => file} <- @metadata["versions"], into: %{} do
            spec_path = Path.join(@specs_openapi_path, file)
            @external_resource spec_path
            {version, spec_path |> File.read!() |> Jason.decode!()}
          end)

  @doc """
  Returns the list of available PVE versions, sorted.

  ## Example

      PveOpenapi.versions()
      #=> ["7.0", "7.1", "7.2", "7.3", "7.4", "8.0", "8.1", "8.2", "8.3", "8.4", "9.0"]
  """
  @spec versions() :: [String.t()]
  def versions, do: @versions

  @doc """
  Returns the parsed OpenAPI spec for the given PVE version.

  Returns `{:ok, spec}` or `{:error, :unknown_version}`.
  """
  @spec spec(String.t()) :: {:ok, map()} | {:error, :unknown_version}
  def spec(version) when is_binary(version) do
    case Map.fetch(@specs, version) do
      {:ok, s} -> {:ok, s}
      :error -> {:error, :unknown_version}
    end
  end

  @doc """
  Returns the parsed OpenAPI spec for the given PVE version.

  Raises on unknown version.
  """
  @spec spec!(String.t()) :: map()
  def spec!(version) when is_binary(version) do
    case spec(version) do
      {:ok, s} -> s
      {:error, :unknown_version} -> raise ArgumentError, "Unknown PVE version: #{version}"
    end
  end

  @doc """
  Returns all endpoints for the given PVE version as `PveOpenapi.Endpoint` structs.
  """
  @spec endpoints(String.t()) :: [PveOpenapi.Endpoint.t()]
  def endpoints(version) when is_binary(version) do
    version |> spec!() |> Spec.endpoints()
  end

  @doc """
  Returns metadata about available specs.
  """
  @spec metadata() :: map()
  def metadata, do: @metadata

  @doc false
  def parse_version(version) do
    version
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
  end
end
