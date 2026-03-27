# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Quality do
  @shortdoc "Analyze response schema quality across PVE versions"
  @moduledoc """
  Analyze response schema quality for PVE API versions.

  ## Usage

      # Summary table for all versions
      mix pve_openapi.quality

      # Detailed report for a specific version
      mix pve_openapi.quality --version 9.0

      # Machine-readable JSON output
      mix pve_openapi.quality --version 9.0 --json

      # List only opaque endpoints
      mix pve_openapi.quality --version 9.0 --opaque-only
  """

  use Mix.Task

  alias PveOpenapi.SchemaQuality

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _} =
      OptionParser.parse(args,
        strict: [version: :string, json: :boolean, opaque_only: :boolean]
      )

    if opts[:version] do
      version_report(opts[:version], opts)
    else
      summary_table()
    end
  end

  defp summary_table do
    Mix.shell().info("Response Schema Quality by PVE Version\n")

    Mix.shell().info(
      String.pad_trailing("Version", 10) <>
        String.pad_trailing("Rich", 8) <>
        String.pad_trailing("Partial", 10) <>
        String.pad_trailing("Opaque", 10) <>
        String.pad_trailing("Total", 8) <>
        "Rich %"
    )

    Mix.shell().info(String.duplicate("-", 56))

    for version <- PveOpenapi.versions() do
      summary = SchemaQuality.quality_summary(version)

      pct =
        if summary.total > 0,
          do: Float.round(summary.rich / summary.total * 100, 1),
          else: 0.0

      Mix.shell().info(
        String.pad_trailing(version, 10) <>
          String.pad_trailing(Integer.to_string(summary.rich), 8) <>
          String.pad_trailing(Integer.to_string(summary.partial), 10) <>
          String.pad_trailing(Integer.to_string(summary.opaque), 10) <>
          String.pad_trailing(Integer.to_string(summary.total), 8) <>
          "#{pct}%"
      )
    end
  end

  defp version_report(version, opts) do
    report = SchemaQuality.quality_report(version)

    report =
      if opts[:opaque_only] do
        Enum.filter(report, &(&1.quality == :opaque))
      else
        report
      end

    if opts[:json] do
      json =
        Enum.map(report, fn r ->
          %{
            "path" => r.path,
            "method" => Atom.to_string(r.method),
            "quality" => Atom.to_string(r.quality),
            "details" => stringify_details(r.details)
          }
        end)
        |> Jason.encode!(pretty: true)

      Mix.shell().info(json)
    else
      label = if opts[:opaque_only], do: "Opaque endpoints", else: "Quality report"
      Mix.shell().info("#{label} for PVE #{version}\n")

      for r <- report do
        method_str = r.method |> Atom.to_string() |> String.upcase() |> String.pad_trailing(7)
        quality_str = r.quality |> Atom.to_string() |> String.pad_trailing(8)
        Mix.shell().info("  #{quality_str} #{method_str} #{r.path}")
      end

      summary = SchemaQuality.quality_summary(version)

      Mix.shell().info(
        "\n#{summary.rich} rich, #{summary.partial} partial, #{summary.opaque} opaque (#{summary.total} total)"
      )
    end
  end

  defp stringify_details(details) do
    for {k, v} <- details, into: %{}, do: {Atom.to_string(k), v}
  end
end
