# Tests

Bash-based smoke tests for the cc-chat helper scripts.

## Run

    ./tests/test-new-topic.sh
    ./tests/test-session-start-context.sh

Each driver creates a temp vault under `$TMPDIR`, invokes the target script,
and asserts file shape / output. Drivers exit non-zero on any failure.
No external test framework. Bash 4+, Python 3 required.
