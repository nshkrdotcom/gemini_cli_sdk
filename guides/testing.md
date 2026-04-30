# Testing Your Application

This guide covers strategies for testing code that uses GeminiCliSdk.

## Mock CLI Approach

Pass an explicit `cli_command` in `GeminiCliSdk.Options` so tests use a local
stub instead of discovering a real `gemini` executable:

```elixir
defmodule MyApp.GeminiTest do
  use ExUnit.Case, async: false

  setup do
    dir = Path.join(System.tmp_dir!(), "my_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    script = """
    #!/bin/sh
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
    opts = %GeminiCliSdk.Options{cli_command: stub_path}

    {:ok, result} = MyApp.ask_gemini("test question", opts)
    assert result =~ "Mock response"
  end
end
```

## JSONL Fixtures

For more realistic tests, create JSONL fixture files that mirror real CLI
output:

```json
{"type":"init","timestamp":"2026-01-01T00:00:00Z","session_id":"test-001","model":"auto-gemini-3"}
{"type":"message","role":"user","content":"hello","timestamp":"2026-01-01T00:00:01Z"}
{"type":"message","role":"assistant","content":"Hello! How can I help?","delta":true,"timestamp":"2026-01-01T00:00:02Z"}
{"type":"result","status":"success","stats":{"total_tokens":50,"input_tokens":10,"output_tokens":40,"duration_ms":500,"tool_calls":0},"timestamp":"2026-01-01T00:00:03Z"}
```

Then serve them from your mock script with a literal fixture path:

```sh
#!/bin/sh
cat > /dev/null
cat "/absolute/path/to/simple_response.jsonl"
```

The stream event parser preserves unknown fields in each event struct's `extra`
map. Fixture-based tests are a good place to assert that future wire fields
round-trip without breaking the known contract.

## Wrapping the SDK

Consider wrapping GeminiCliSdk behind a behaviour for easier testing:

```elixir
defmodule MyApp.AI do
  @callback ask(String.t(), GeminiCliSdk.Options.t()) ::
              {:ok, String.t()} | {:error, term()}
end

defmodule MyApp.AI.Gemini do
  @behaviour MyApp.AI

  @impl true
  def ask(prompt, opts) do
    GeminiCliSdk.run(prompt, opts)
  end
end

defmodule MyApp.AI.Mock do
  @behaviour MyApp.AI

  @impl true
  def ask(_prompt, _opts), do: {:ok, "Mock response"}
end
```

Then in your application code:

```elixir
defmodule MyApp.Feature do
  @ai_module Application.compile_env(:my_app, :ai_module, MyApp.AI.Gemini)

  def process(input, opts \\ %GeminiCliSdk.Options{}) do
    @ai_module.ask("Process: #{input}", opts)
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
