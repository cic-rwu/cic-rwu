#!/usr/bin/env bash
##[demos/jeopardy/jeopardy.sh]
# set up the Jeopardy demo (builds .venv on first run) and open a shell inside it
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
VENV=.venv

# a venv that was moved or half-built fails here, and gets rebuilt below
venv_works() { "$VENV/bin/jeopardy-server" --help &>/dev/null; }

if ! venv_works; then
  if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
    echo "jeopardy needs python3 3.11 or newer" >&2
    exit 1
  fi
  echo "Setting up Jeopardy (first run only)..."
  python3 -m venv --clear "$VENV" || {
    echo "could not create a venv (Debian/Ubuntu: apt install python3-venv)" >&2
    exit 1
  }
  "$VENV/bin/pip" install --quiet --disable-pip-version-check -e .
fi

cat <<'EOF'

  Welcome to CIC Jeopardy!

    jeopardy-server               start a game
    jeopardy-client               join a game (use another terminal)
    jeopardy-validate games/*     check question sets

  Type 'exit' to leave.

EOF

exec bash --init-file "$VENV/bin/activate" -i
