# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.FeatureMatrix do
  @moduledoc """
  High-level feature availability queries across PVE versions.

  Maps semantic feature atoms (e.g., `:sdn`, `:notification_system`) to
  their availability across versions by checking whether indicator endpoints
  exist in each version's spec.

  ## Usage

      PveOpenapi.FeatureMatrix.feature_available?(:sdn_fabrics, "9.0")
      #=> true

      PveOpenapi.FeatureMatrix.feature_added_in(:notification_system)
      #=> "8.1"

      PveOpenapi.FeatureMatrix.features_for_version("9.0")
      #=> [:acl_management, :backup_info, :backup_management, ...]

      PveOpenapi.FeatureMatrix.feature_diff("8.4", "9.0")
      #=> %{added: [:ha_rules, :sdn_fabrics], removed: []}
  """

  alias PveOpenapi.FeatureMatrix.Catalog
  alias PveOpenapi.VersionMatrix

  @catalog Catalog.default()

  # Build compile-time lookup: %{feature_atom => [versions where available]}
  @feature_versions (
                      versions = PveOpenapi.versions()

                      for {feature, indicator_paths} <- @catalog, into: %{} do
                        available_versions =
                          Enum.filter(versions, fn version ->
                            Enum.any?(indicator_paths, fn path ->
                              # Check any HTTP method
                              Enum.any?([:get, :post, :put, :delete], fn method ->
                                VersionMatrix.endpoint_available?(path, method, version)
                              end)
                            end)
                          end)

                        {feature, available_versions}
                      end
                    )

  @doc """
  Check if a feature is available in a given PVE version.
  """
  @spec feature_available?(atom(), String.t()) :: boolean()
  def feature_available?(feature, version) do
    case Map.fetch(@feature_versions, feature) do
      {:ok, versions} -> version in versions
      :error -> false
    end
  end

  @doc """
  Return the earliest version where a feature became available.

  Returns `nil` if the feature is unknown or never available.
  """
  @spec feature_added_in(atom()) :: String.t() | nil
  def feature_added_in(feature) do
    case Map.fetch(@feature_versions, feature) do
      {:ok, [first | _]} -> first
      {:ok, []} -> nil
      :error -> nil
    end
  end

  @doc """
  Return all features available in a given version.

  Accepts an optional custom catalog (defaults to `Catalog.default()`).
  """
  @spec features_for_version(String.t(), [Catalog.rule()] | nil) :: [atom()]
  def features_for_version(version, catalog \\ nil)

  def features_for_version(version, nil) do
    @feature_versions
    |> Enum.filter(fn {_feature, versions} -> version in versions end)
    |> Enum.map(fn {feature, _} -> feature end)
    |> Enum.sort()
  end

  def features_for_version(version, catalog) when is_list(catalog) do
    Enum.filter(catalog, fn {_feature, indicator_paths} ->
      any_path_available?(indicator_paths, version)
    end)
    |> Enum.map(fn {feature, _} -> feature end)
    |> Enum.sort()
  end

  defp any_path_available?(paths, version) do
    Enum.any?(paths, fn path ->
      Enum.any?([:get, :post, :put, :delete], fn method ->
        VersionMatrix.endpoint_available?(path, method, version)
      end)
    end)
  end

  @doc """
  Return features added and removed between two versions.
  """
  @spec feature_diff(String.t(), String.t()) :: %{added: [atom()], removed: [atom()]}
  def feature_diff(from_version, to_version) do
    from_features = features_for_version(from_version) |> MapSet.new()
    to_features = features_for_version(to_version) |> MapSet.new()

    %{
      added: MapSet.difference(to_features, from_features) |> MapSet.to_list() |> Enum.sort(),
      removed: MapSet.difference(from_features, to_features) |> MapSet.to_list() |> Enum.sort()
    }
  end

  @doc """
  Return all known features and their availability.
  """
  @spec all_features() :: %{atom() => [String.t()]}
  def all_features, do: @feature_versions
end
