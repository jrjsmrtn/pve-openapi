# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Diff do
  @shortdoc "Generate version diff JSON files"
  @moduledoc """
  Generate JSON diff files for consecutive PVE version pairs.

  ## Usage

      # Generate diffs for all consecutive version pairs
      mix pve_openapi.diff --all

      # Generate diff for a specific pair
      mix pve_openapi.diff --from 8.3 --to 8.4

  Output is written to `specs/diffs/diff-{from}-{to}.json`.
  """

  use Mix.Task

  @diffs_dir Path.join(["specs", "diffs"])

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _} =
      OptionParser.parse(args, strict: [all: :boolean, from: :string, to: :string])

    File.mkdir_p!(@diffs_dir)

    pairs = resolve_pairs(opts)

    if pairs == [] do
      Mix.shell().error("No version pairs to diff. Use --all or --from/--to.")
      exit({:shutdown, 1})
    end

    for {from, to} <- pairs do
      generate_diff(from, to)
    end

    Mix.shell().info("Generated #{length(pairs)} diff file(s) in #{@diffs_dir}/")
  end

  defp resolve_pairs(opts) do
    cond do
      opts[:all] ->
        versions = PveOpenapi.versions()
        Enum.zip(versions, tl(versions))

      opts[:from] && opts[:to] ->
        [{opts[:from], opts[:to]}]

      true ->
        []
    end
  end

  defp generate_diff(from, to) do
    Mix.shell().info("Diffing #{from} → #{to}...")

    diff = PveOpenapi.Diff.full_diff(from, to)

    output =
      diff
      |> serialize_diff()
      |> Jason.encode!(pretty: true)

    path = Path.join(@diffs_dir, "diff-#{from}-#{to}.json")
    File.write!(path, output <> "\n")

    Mix.shell().info(
      "  #{diff.summary.added} added, #{diff.summary.removed} removed, " <>
        "#{diff.summary.parameter_changes} param changes, #{diff.summary.breaking} breaking"
    )
  end

  defp serialize_diff(diff) do
    %{
      "from" => diff.from,
      "to" => diff.to,
      "generated_at" => Date.utc_today() |> Date.to_iso8601(),
      "summary" => %{
        "added" => diff.summary.added,
        "removed" => diff.summary.removed,
        "parameter_changes" => diff.summary.parameter_changes,
        "breaking" => diff.summary.breaking
      },
      "added_endpoints" =>
        Enum.map(diff.added_endpoints, fn ep ->
          %{"path" => ep.path, "method" => Atom.to_string(ep.method)}
        end),
      "removed_endpoints" =>
        Enum.map(diff.removed_endpoints, fn ep ->
          %{"path" => ep.path, "method" => Atom.to_string(ep.method)}
        end),
      "parameter_changes" =>
        Enum.map(diff.parameter_changes, fn pc ->
          %{
            "path" => pc.path,
            "method" => Atom.to_string(pc.method),
            "changes" => Enum.map(pc.changes, &serialize_change/1)
          }
        end),
      "breaking_changes" =>
        Enum.map(diff.breaking_changes, fn bc ->
          change = %{"type" => Atom.to_string(bc.type), "path" => bc.path}

          change =
            if bc[:method], do: Map.put(change, "method", Atom.to_string(bc.method)), else: change

          if bc[:parameter], do: Map.put(change, "parameter", bc.parameter), else: change
        end)
    }
  end

  defp serialize_change(change) do
    base = %{"type" => Atom.to_string(change.type), "name" => change.name}

    case change.type do
      :param_added ->
        Map.put(base, "required", change.required)

      :param_removed ->
        base

      :type_changed ->
        base |> Map.put("from", change.from) |> Map.put("to", change.to)

      :became_required ->
        base

      :constraint_changed ->
        base
        |> Map.put("field", change.field)
        |> Map.put("from", change.from)
        |> Map.put("to", change.to)
    end
  end
end
