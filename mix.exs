defmodule GeminiCliSdk.MixProject do
  use Mix.Project

  @app :gemini_cli_sdk
  @version "0.2.0"
  @source_url "https://github.com/nshkrdotcom/gemini_cli_sdk"
  @homepage_url "https://hex.pm/packages/gemini_cli_sdk"
  @docs_url "https://hexdocs.pm/gemini_cli_sdk"
  @cli_subprocess_core_version "~> 0.1.0"
  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      homepage_url: @homepage_url,
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {GeminiCliSdk.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.live": :test,
        "run.live": :dev
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      cli_subprocess_core_dep(),
      {:jason, "~> 1.4"},
      {:zoi, "~> 0.17"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp cli_subprocess_core_dep do
    case local_dep_path("../cli_subprocess_core") do
      nil -> {:cli_subprocess_core, @cli_subprocess_core_version}
      path -> {:cli_subprocess_core, path: path}
    end
  end

  defp local_dep_path(relative_path) do
    if local_workspace_deps?() do
      path = Path.expand(relative_path, __DIR__)
      if File.dir?(path), do: path
    end
  end

  defp local_workspace_deps? do
    not hex_packaging_task?() and not Enum.member?(Path.split(__DIR__), "deps")
  end

  defp hex_packaging_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp description do
    "An Elixir SDK for the Gemini CLI - build AI-powered applications with Google Gemini."
  end

  defp package do
    [
      name: "gemini_cli_sdk",
      description: description(),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Hex" => @homepage_url,
        "HexDocs" => @docs_url,
        "Gemini CLI" => "https://github.com/google-gemini/gemini-cli",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["nshkrdotcom"],
      files: ~w(lib assets mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "GeminiCliSdk",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @homepage_url,
      assets: %{"assets" => "assets"},
      logo: "assets/gemini_cli_sdk.svg",
      extras: [
        "README.md": [title: "Overview"],
        "guides/getting-started.md": [title: "Getting Started"],
        "guides/streaming.md": [title: "Streaming"],
        "guides/synchronous.md": [title: "Synchronous Execution"],
        "guides/options.md": [title: "Options"],
        "guides/models.md": [title: "Models"],
        "guides/configuration.md": [title: "Configuration"],
        "guides/sessions.md": [title: "Sessions"],
        "guides/error-handling.md": [title: "Error Handling"],
        "guides/architecture.md": [title: "Architecture"],
        "guides/testing.md": [title: "Testing"],
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],
      groups_for_extras: [
        "Project Overview": ["README.md"],
        Foundations: [
          "guides/getting-started.md",
          "guides/options.md",
          "guides/models.md",
          "guides/configuration.md"
        ],
        Runtime: [
          "guides/streaming.md",
          "guides/synchronous.md",
          "guides/sessions.md",
          "guides/error-handling.md"
        ],
        Operations: [
          "guides/architecture.md",
          "guides/testing.md"
        ],
        Reference: ["CHANGELOG.md", "LICENSE"]
      ],
      groups_for_modules: [
        "Public API": [GeminiCliSdk],
        Types: [
          GeminiCliSdk.Types,
          GeminiCliSdk.Types.InitEvent,
          GeminiCliSdk.Types.MessageEvent,
          GeminiCliSdk.Types.ToolUseEvent,
          GeminiCliSdk.Types.ToolResultEvent,
          GeminiCliSdk.Types.ErrorEvent,
          GeminiCliSdk.Types.ResultEvent,
          GeminiCliSdk.Types.Stats
        ],
        Errors: [GeminiCliSdk.Error],
        Configuration: [
          GeminiCliSdk.Options,
          GeminiCliSdk.Models,
          GeminiCliSdk.Configuration,
          GeminiCliSdk.CLI,
          GeminiCliSdk.ArgBuilder,
          GeminiCliSdk.Env,
          GeminiCliSdk.Config
        ],
        Internals: [
          GeminiCliSdk.Stream,
          GeminiCliSdk.Runtime.CLI,
          GeminiCliSdk.Command,
          GeminiCliSdk.Session
        ]
      ],
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;

      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp before_closing_body_tag(:html), do: ""

  defp before_closing_body_tag(:epub), do: ""

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      plt_core_path: "priv/plts/core",
      plt_local_path: "priv/plts"
    ]
  end
end
