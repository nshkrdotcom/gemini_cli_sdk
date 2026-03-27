defmodule GeminiCliSdk.TestSupport do
  @moduledoc false

  @global_state_lock {:gemini_cli_sdk_test, :global_state}

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
  Temporarily sets environment variables, runs the function, then restores
  the original values.
  """
  def with_env(env, fun) when is_function(fun, 0) do
    :global.trans(@global_state_lock, fn ->
      saved = Enum.map(env, fn {k, _} -> {k, System.get_env(k)} end)

      Enum.each(env, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)

      try do
        fun.()
      after
        Enum.each(saved, fn
          {k, nil} -> System.delete_env(k)
          {k, v} -> System.put_env(k, v)
        end)
      end
    end)
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
end
