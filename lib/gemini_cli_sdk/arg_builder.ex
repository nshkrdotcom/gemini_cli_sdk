defmodule GeminiCliSdk.ArgBuilder do
  @moduledoc "Converts an `Options` struct into a list of CLI arguments."

  alias GeminiCliSdk.Options

  @spec build_args(Options.t(), String.t() | nil) :: [String.t()]
  def build_args(%Options{} = opts, prompt \\ nil) do
    []
    |> add_prompt_flag(prompt)
    |> add_output_format(opts)
    |> add_model(opts)
    |> add_approval_mode(opts)
    |> add_yolo(opts)
    |> add_sandbox(opts)
    |> add_resume(opts)
    |> add_extensions(opts)
    |> add_include_directories(opts)
    |> add_allowed_tools(opts)
    |> add_allowed_mcp_server_names(opts)
    |> add_debug(opts)
  end

  defp add_prompt_flag(args, nil), do: args
  defp add_prompt_flag(args, prompt), do: args ++ ["--prompt", prompt]

  defp add_output_format(args, %Options{output_format: fmt}) when is_binary(fmt) do
    args ++ ["--output-format", fmt]
  end

  defp add_output_format(args, _opts), do: args ++ ["--output-format", "stream-json"]

  defp add_model(args, %Options{} = opts) do
    case resolved_model(opts) do
      model when model in [nil, "", "nil", "null"] -> args
      model -> args ++ ["--model", model]
    end
  end

  defp add_approval_mode(args, %Options{approval_mode: nil}), do: args

  defp add_approval_mode(args, %Options{approval_mode: mode}) do
    args ++ ["--approval-mode", Atom.to_string(mode)]
  end

  defp add_yolo(args, %Options{yolo: true, approval_mode: nil}), do: args ++ ["--yolo"]
  defp add_yolo(args, _opts), do: args

  defp add_sandbox(args, %Options{sandbox: true}), do: args ++ ["--sandbox"]
  defp add_sandbox(args, _opts), do: args

  defp add_resume(args, %Options{resume: nil}), do: args
  defp add_resume(args, %Options{resume: true}), do: args ++ ["--resume"]
  defp add_resume(args, %Options{resume: "latest"}), do: args ++ ["--resume"]
  defp add_resume(args, %Options{resume: id}) when is_binary(id), do: args ++ ["--resume", id]

  defp add_extensions(args, %Options{extensions: []}), do: args

  defp add_extensions(args, %Options{extensions: exts}) do
    Enum.reduce(exts, args, fn ext, acc -> acc ++ ["--extensions", ext] end)
  end

  defp add_include_directories(args, %Options{include_directories: []}), do: args

  defp add_include_directories(args, %Options{include_directories: dirs}) do
    args ++ ["--include-directories", Enum.join(dirs, ",")]
  end

  defp add_allowed_tools(args, %Options{allowed_tools: []}), do: args

  defp add_allowed_tools(args, %Options{allowed_tools: tools}) do
    args ++ ["--allowed-tools", Enum.join(tools, ",")]
  end

  defp add_allowed_mcp_server_names(args, %Options{allowed_mcp_server_names: []}), do: args

  defp add_allowed_mcp_server_names(args, %Options{allowed_mcp_server_names: names}) do
    args ++ ["--allowed-mcp-server-names", Enum.join(names, ",")]
  end

  defp add_debug(args, %Options{debug: true}), do: args ++ ["--debug"]
  defp add_debug(args, _opts), do: args

  defp resolved_model(%Options{model_payload: payload}) when is_map(payload) do
    Map.get(payload, :resolved_model, Map.get(payload, "resolved_model"))
  end

  defp resolved_model(%Options{model: model}), do: model
end
