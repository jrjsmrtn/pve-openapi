# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.MixProject do
  use Mix.Project

  @version "0.2.1"

  def project do
    [
      app: :pve_openapi,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Package
      name: "PveOpenapi",
      source_url: "https://github.com/jrjsmrtn/pve-openapi",
      licenses: ["Apache-2.0"],
      docs: docs(),

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},

      # .deb extraction (XZ/LZMA and Zstd decompression)
      {:xz, "~> 0.4"},
      {:ezstd, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    []
  end

  defp docs do
    [
      main: "PveOpenapi",
      extras: [
        "README.md",
        "docs/adr/0001-record-architecture-decisions.md",
        "docs/adr/0002-pve-openapi-as-single-source-of-truth.md"
      ]
    ]
  end
end
