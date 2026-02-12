# Testing Your Application

This guide covers strategies for testing code that uses GeminiCliSdk.

## Mock CLI Approach

GeminiCliSdk resolves the CLI binary via the `GEMINI_CLI_PATH` environment variable. You can point this at a mock script for testing:

```elixir
defmodule MyApp.GeminiTest do
  use ExUnit.Case, async: false

  setup do
    dir = Path.join(System.tmp_dir!(), "my_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    script = """
    #!/usr/bin/env bash
    cat > /dev/null
    echo '{"type":"init","session_id":"test","model":"test"}'
    echo '{"type":"message","role":"assistant","content":"Mock response","delta":true}'
    echo '{"type":"result","status":"success","stats":{"total_tokens":10}}'
    """

    path = Path.join(dir, "gemini")
    File.write!(path, script)
    File.chmod!(path, 0o755)

    on_exit(fn -> File.rm_rf(dir) end)

    %{stub_path: path}
  end

  test "my feature uses Gemini", %{stub_path: stub_path} do
    original = System.get_env("GEMINI_CLI_PATH")
    System.put_env("GEMINI_CLI_PATH", stub_path)

    try do
      {:ok, result} = MyApp.ask_gemini("test question")
      assert result =~ "Mock response"
    after
      if original, do: System.put_env("GEMINI_CLI_PATH", original),
        else: System.delete_env("GEMINI_CLI_PATH")
    end
  end
end
```

## JSONL Fixtures

For more realistic tests, create JSONL fixture files that mirror real CLI output:

```json
{"type":"init","timestamp":"2026-01-01T00:00:00Z","session_id":"test-001","model":"gemini-2.5-pro"}
{"type":"message","role":"user","content":"hello","timestamp":"2026-01-01T00:00:01Z"}
{"type":"message","role":"assistant","content":"Hello! How can I help?","delta":true,"timestamp":"2026-01-01T00:00:02Z"}
{"type":"result","status":"success","stats":{"total_tokens":50,"input_tokens":10,"output_tokens":40,"duration_ms":500,"tool_calls":0},"timestamp":"2026-01-01T00:00:03Z"}
```

Then serve them from your mock script:

```bash
#!/usr/bin/env bash
cat > /dev/null
while IFS= read -r line || [ -n "$line" ]; do
  echo "$line"
done < "$GEMINI_TEST_STREAM_FILE"
```

## Wrapping the SDK

Consider wrapping GeminiCliSdk behind a behaviour for easier testing:

```elixir
defmodule MyApp.AI do
  @callback ask(String.t()) :: {:ok, String.t()} | {:error, term()}
end

defmodule MyApp.AI.Gemini do
  @behaviour MyApp.AI

  @impl true
  def ask(prompt) do
    GeminiCliSdk.run(prompt, %GeminiCliSdk.Options{model: GeminiCliSdk.Models.fast_model()})
  end
end

defmodule MyApp.AI.Mock do
  @behaviour MyApp.AI

  @impl true
  def ask(_prompt), do: {:ok, "Mock response"}
end
```

Then in your application code:

```elixir
defmodule MyApp.Feature do
  @ai_module Application.compile_env(:my_app, :ai_module, MyApp.AI.Gemini)

  def process(input) do
    @ai_module.ask("Process: #{input}")
  end
end
```

## Live Integration Tests

For tests that run against the real CLI, tag them and exclude by default:

```elixir
# test/test_helper.exs
ExUnit.start(exclude: [:live])

# test/live/gemini_live_test.exs
defmodule GeminiLiveTest do
  use ExUnit.Case, async: false

  @moduletag :live

  test "real CLI responds" do
    {:ok, response} = GeminiCliSdk.run("Say hello")
    assert is_binary(response)
    assert byte_size(response) > 0
  end
end
```

Run live tests with:

```bash
mix test --only live
```
