# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Clean do
  @moduledoc """
  Remove all generated spec artifacts.

  Deletes `specs/raw/`, `specs/openapi/`, and `specs/metadata.json`.

  ## Usage

      mix pve_openapi.clean
  """
  @shortdoc "Remove all generated spec artifacts"

  use Mix.Task

  @dirs ~w(specs/raw specs/openapi)
  @files ~w(specs/metadata.json)

  @impl Mix.Task
  def run(_args) do
    for dir <- @dirs, File.dir?(dir) do
      File.rm_rf!(dir)
      Mix.shell().info("Removed #{dir}/")
    end

    for file <- @files, File.exists?(file) do
      File.rm!(file)
      Mix.shell().info("Removed #{file}")
    end
  end
end
