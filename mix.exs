defmodule GeminiCliSdk.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/gemini_cli_sdk"
  @homepage_url "https://hex.pm/packages/gemini_cli_sdk"
  @docs_url "https://hexdocs.pm/gemini_cli_sdk"
  @cli_subprocess_core_requirement "~> 0.1.0"
  @cli_subprocess_core_repo "nshkrdotcom/cli_subprocess_core"
  @cli_subprocess_core_ref "d5f7c5daa810965f60503bd4499c42ca3c4f5574"
  def project do
    [
      app: :gemini_cli_sdk,
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
      workspace_dep(
        :cli_subprocess_core,
        "../cli_subprocess_core",
        @cli_subprocess_core_requirement,
        github: @cli_subprocess_core_repo,
        ref: @cli_subprocess_core_ref
      ),
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
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
      files:
        ~w(lib guides assets examples/README.md mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
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
        "README.md",
        "guides/getting-started.md",
        "guides/streaming.md",
        "guides/synchronous.md",
        "guides/options.md",
        "guides/models.md",
        "guides/configuration.md",
        "guides/sessions.md",
        "guides/error-handling.md",
        "guides/architecture.md",
        "guides/testing.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Introduction: [
          "README.md",
          "guides/getting-started.md"
        ],
        Guides: [
          "guides/streaming.md",
          "guides/synchronous.md",
          "guides/options.md",
          "guides/models.md",
          "guides/configuration.md",
          "guides/sessions.md",
          "guides/error-handling.md"
        ],
        Advanced: [
          "guides/architecture.md",
          "guides/testing.md"
        ],
        "Release Notes": ["CHANGELOG.md", "LICENSE"]
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
          GeminiCliSdk.Session,
          GeminiCliSdk.Transport,
          GeminiCliSdk.Transport.Erlexec
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
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end

  defp workspace_dep(app, path, requirement, opts) do
    {release_opts, dep_opts} = Keyword.split(opts, [:github, :git, :branch, :tag, :ref])
    expanded_path = Path.expand(path, __DIR__)

    cond do
      hex_packaging?() ->
        {app, requirement, dep_opts}

      File.dir?(expanded_path) ->
        {app, Keyword.put(dep_opts, :path, path)}

      true ->
        {app, Keyword.merge(dep_opts, release_opts)}
    end
  end

  defp hex_packaging? do
    Enum.any?(System.argv(), &String.starts_with?(&1, "hex."))
  end
end
