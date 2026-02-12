defmodule GeminiCliSdk.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :gemini_cli_sdk,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "An Elixir SDK for the Gemini CLI — Build AI-powered applications with Google Gemini",
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      source_url: "https://github.com/nshkrdotcom/gemini_cli_sdk"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
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
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "gemini_cli_sdk",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nshkrdotcom/gemini_cli_sdk"
      },
      maintainers: [{"NSHkr", "ZeroTrust@NSHkr.com"}],
      files: ~w(lib assets mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "GeminiCliSdk",
      source_ref: "v#{@version}",
      source_url: "https://github.com/nshkrdotcom/gemini_cli_sdk",
      homepage_url: "https://hex.pm/packages/gemini_cli_sdk",
      assets: %{"assets" => "assets"},
      logo: "assets/gemini_cli_sdk.svg",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md"
        ],
        "Release Notes": ["CHANGELOG.md", "LICENSE"]
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
end
