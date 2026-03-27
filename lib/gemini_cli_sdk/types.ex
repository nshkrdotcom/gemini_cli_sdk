defmodule GeminiCliSdk.Types do
  @moduledoc "Type definitions and stream event parsing for the Gemini CLI SDK."

  alias __MODULE__.{
    InitEvent,
    MessageEvent,
    ToolUseEvent,
    ToolResultEvent,
    ErrorEvent,
    ResultEvent
  }

  @type stream_event ::
          InitEvent.t()
          | MessageEvent.t()
          | ToolUseEvent.t()
          | ToolResultEvent.t()
          | ErrorEvent.t()
          | ResultEvent.t()

  @event_modules %{
    "init" => InitEvent,
    "message" => MessageEvent,
    "tool_use" => ToolUseEvent,
    "tool_result" => ToolResultEvent,
    "error" => ErrorEvent,
    "result" => ResultEvent
  }

  @spec parse_event(String.t()) :: {:ok, stream_event()} | {:error, GeminiCliSdk.Error.t()}
  def parse_event(json_line) when is_binary(json_line) do
    case Jason.decode(json_line) do
      {:ok, data} ->
        parse_event_data(data)

      {:error, reason} ->
        {:error,
         %GeminiCliSdk.Error{
           kind: :json_decode_error,
           message: "Failed to decode JSON: #{inspect(reason)}",
           cause: reason
         }}
    end
  end

  defp parse_event_data(%{"type" => type} = data) when is_map_key(@event_modules, type) do
    module = Map.fetch!(@event_modules, type)

    case module.parse(data) do
      {:ok, event} ->
        {:ok, event}

      {:error, {_tag, details}} ->
        {:error,
         %GeminiCliSdk.Error{
           kind: :invalid_event,
           message: "Invalid #{type} event: #{details.message}",
           cause: details
         }}
    end
  end

  defp parse_event_data(%{"type" => type}) do
    {:error,
     %GeminiCliSdk.Error{
       kind: :unknown_event_type,
       message: "Unknown event type: #{type}",
       cause: type
     }}
  end

  defp parse_event_data(_) do
    {:error,
     %GeminiCliSdk.Error{
       kind: :invalid_event,
       message: "Missing type field in event",
       cause: :missing_type_field
     }}
  end

  @spec final_event?(stream_event()) :: boolean()
  def final_event?(%ResultEvent{}), do: true
  def final_event?(%ErrorEvent{severity: "fatal"}), do: true
  def final_event?(_), do: false
end
