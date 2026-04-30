defmodule GeminiCliSdk.TestSupport do
  @moduledoc false

  @doc """
  Creates a unique temporary directory. Returns the absolute path.
  Caller is responsible for cleanup via `File.rm_rf/1`.
  """
  def tmp_dir!(prefix \\ "gemini_cli_sdk_test") do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{suffix}")
    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Writes a file to `dir/name` with the given content. Returns the absolute path.
  """
  def write_file!(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)
    path
  end

  @doc """
  Writes an executable file (chmod 755). Returns the absolute path.
  """
  def write_executable!(dir, name, content) do
    path = write_file!(dir, name, content)
    File.chmod!(path, 0o755)
    path
  end

  @doc """
  Writes a deterministic Gemini CLI test double.

  The generated script is configured entirely through literal paths and values
  embedded at creation time. It does not read test-control environment
  variables.
  """
  def write_cli_stub!(dir, opts \\ []) do
    name = Keyword.get(opts, :name, "gemini")
    args_file = Keyword.get(opts, :args_file)
    stdin_file = Keyword.get(opts, :stdin_file)
    pid_file = Keyword.get(opts, :pid_file)
    stream_file = Keyword.get(opts, :stream_file)
    output_file = Keyword.get(opts, :output_file)
    output = Keyword.get(opts, :output)
    stderr = Keyword.get(opts, :stderr)
    exit_code = Keyword.get(opts, :exit_code, 0)
    block? = Keyword.get(opts, :block?, false)

    script = """
    #!/bin/sh
    set -eu
    #{write_pid(pid_file)}
    #{write_args(args_file)}
    #{write_stdin(stdin_file)}
    #{maybe_block(block?)}
    #{write_stderr(stderr)}
    exit_code=#{exit_code}
    #{write_stream(stream_file)}
    #{write_output_file(output_file)}
    #{write_output(output)}
    exit "$exit_code"
    """

    write_executable!(dir, name, script)
  end

  @doc """
  Polls `fun` every `poll_interval_ms` until it returns truthy or `timeout_ms`
  is exceeded.
  """
  def wait_until(fun, timeout_ms, poll_interval_ms \\ 20)
      when is_function(fun, 0) and is_integer(timeout_ms) and timeout_ms >= 0 do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(fun, deadline, poll_interval_ms)
  end

  defp do_wait_until(fun, deadline, poll_interval_ms) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        :timeout
      else
        Process.sleep(poll_interval_ms)
        do_wait_until(fun, deadline, poll_interval_ms)
      end
    end
  end

  @doc """
  Returns the absolute path to a fixture file in test/support/fixtures/.
  """
  def fixture_path(name) do
    Path.join([File.cwd!(), "test", "support", "fixtures", name])
  end

  @doc """
  Reads a fixture file and returns its content as a string.
  """
  def read_fixture!(name) do
    name |> fixture_path() |> File.read!()
  end

  @doc """
  Checks whether an OS process (by integer PID) is still alive.
  """
  def os_process_alive?(pid) when is_integer(pid) do
    case System.cmd("kill", ["-0", Integer.to_string(pid)], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  @doc """
  Sends SIGKILL to an OS process by integer PID.
  """
  def kill_os_process(pid) when is_integer(pid) do
    _ = System.cmd("kill", ["-9", Integer.to_string(pid)], stderr_to_stdout: true)
    :ok
  end

  defp write_pid(nil), do: ""
  defp write_pid(path), do: "printf '%s\\n' $$ > #{shell_quote(path)}"

  defp write_args(nil), do: ""
  defp write_args(path), do: "printf '%s\\n' \"$@\" > #{shell_quote(path)}"

  defp write_stdin(nil), do: "cat > /dev/null || true"
  defp write_stdin(path), do: "cat > #{shell_quote(path)}"

  defp maybe_block(false), do: ""
  defp maybe_block(true), do: "tail -f /dev/null"

  defp write_stderr(nil), do: ""
  defp write_stderr(text), do: "printf '%s\\n' #{shell_quote(text)} >&2"

  defp write_stream(nil), do: ""

  defp write_stream(path) do
    """
    if [ -f #{shell_quote(path)} ]; then
      cat #{shell_quote(path)}
      exit "$exit_code"
    fi
    """
  end

  defp write_output_file(nil), do: ""

  defp write_output_file(path) do
    """
    if [ -f #{shell_quote(path)} ]; then
      cat #{shell_quote(path)}
      exit "$exit_code"
    fi
    """
  end

  defp write_output(nil), do: ""
  defp write_output(text), do: "printf '%s\\n' #{shell_quote(text)}"

  defp shell_quote(value) do
    "'" <> String.replace(to_string(value), "'", "'\"'\"'") <> "'"
  end
end
