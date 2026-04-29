defmodule GeminiCliSdk.Models do
  @moduledoc """
  Centralized model name constants and helpers.

  All model references throughout the SDK flow through this module.
  If the shared core registry is unavailable, fallback defaults can be supplied
  via Application configuration:

      # config/config.exs
      config :gemini_cli_sdk,
        default_model: "auto-gemini-3",
        fast_model: "gemini-3.1-flash-lite-preview"

  ## Built-in Models

  | Function | Default | Description |
  |----------|---------|-------------|
  | `default_model/0` | `"auto-gemini-3"` | Gemini CLI automatic Gemini 3 routing |
  | `fast_model/0` | `"gemini-3.1-flash-lite-preview"` | Optimized for speed |

  ## Aliases

  Local convenience aliases expand through `resolve/1`. Gemini CLI aliases
  such as `"pro"` and `"flash"` are validated and passed through unchanged:

  | Alias | Resolves To |
  |-------|-------------|
  | `"default"` | `default_model()` |
  | `"fast"` | `fast_model()` |
  """

  alias CliSubprocessCore.ModelRegistry

  @default_model "auto-gemini-3"
  @fast_model "gemini-3.1-flash-lite-preview"

  @aliases %{
    "default" => @default_model,
    "fast" => @fast_model
  }

  @doc "Returns the default (most capable) model name."
  @spec default_model() :: String.t()
  def default_model do
    case ModelRegistry.default_model(:gemini) do
      {:ok, model} -> model
      {:error, _reason} -> Application.get_env(:gemini_cli_sdk, :default_model, @default_model)
    end
  end

  @doc "Returns the fast model name, optimized for speed."
  @spec fast_model() :: String.t()
  def fast_model do
    resolve("fast")
  end

  @doc "Returns a list of all built-in model identifiers."
  @spec available_models() :: [String.t()]
  def available_models do
    case ModelRegistry.list_visible(:gemini, visibility: :all) do
      {:ok, models} -> models
      {:error, _reason} -> [default_model(), fast_model()] |> Enum.uniq()
    end
  end

  @doc """
  Resolves a model name, expanding aliases.

  Accepts full model names as-is, Gemini CLI virtual models like
  `"auto-gemini-3"`, and local convenience aliases like `"default"` and
  `"fast"`.

  ## Examples

      iex> GeminiCliSdk.Models.resolve("pro")
      "pro"

      iex> GeminiCliSdk.Models.resolve("gemini-3.1-flash-lite-preview")
      "gemini-3.1-flash-lite-preview"

      iex> GeminiCliSdk.Models.resolve("auto-gemini-3")
      "auto-gemini-3"
  """
  @spec resolve(String.t()) :: String.t()
  def resolve(name) when is_binary(name) do
    case ModelRegistry.validate(:gemini, Map.get(@aliases, name, name)) do
      {:ok, model} -> model.id
      {:error, _reason} -> name
    end
  end

  @doc """
  Validates a model value.

  Accepts `nil` (meaning use CLI default) or a model known to the shared core
  registry. Unknown strings are rejected before the CLI is started.

  ## Examples

      iex> GeminiCliSdk.Models.validate("gemini-3.1-flash-lite-preview")
      :ok

      iex> GeminiCliSdk.Models.validate(nil)
      :ok

      iex> GeminiCliSdk.Models.validate(123)
      {:error, "Invalid model: 123. Must be a non-empty string or nil."}
  """
  @spec validate(term()) :: :ok | {:error, String.t()}
  def validate(nil), do: :ok

  def validate(model) do
    case ModelRegistry.validate(:gemini, model) do
      {:ok, _model} -> :ok
      {:error, reason} -> {:error, "Invalid model: #{inspect(model)} (#{inspect(reason)})"}
    end
  end

  @doc "Returns `true` if the model name is a known built-in model or alias."
  @spec known?(String.t()) :: boolean()
  def known?(model) when is_binary(model) do
    model = Map.get(@aliases, model, model)

    case ModelRegistry.validate(:gemini, model) do
      {:ok, _model} -> true
      {:error, _reason} -> false
    end
  end
end
