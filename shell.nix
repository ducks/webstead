{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    ruby_3_3
    postgresql_16
    redis
    nodejs_22
    libyaml
    libffi
    zlib
    openssl
    readline
    bundler
  ];

  shellHook = ''
    # Set up NPM for LLM CLIs
    export NPM_CONFIG_PREFIX=$HOME/.npm-global
    export PATH=$HOME/.local/bin:$NPM_CONFIG_PREFIX/bin:$PATH

    # Allow claude CLI to run inside Claude Code session
    unset CLAUDECODE

    mkdir -p $NPM_CONFIG_PREFIX

    # Install codex if not present
    if ! command -v codex &> /dev/null; then
      echo "Installing Codex CLI..."
      npm i -g @openai/codex
    fi

    # Install gemini CLI if not present
    if ! npm list -g @google/gemini-cli &> /dev/null 2>&1; then
      echo "Installing Gemini CLI..."
      npm i -g @google/gemini-cli
    fi

    echo "Webstead Development Environment"
    echo "================================="
    echo "Ruby: $(ruby --version)"
    echo "PostgreSQL: $(postgres --version | head -n1)"
    echo "Redis: $(redis-server --version)"
    echo "Node: $(node --version)"
    echo ""

    export PGDATA="$PWD/tmp/postgres"
    export PGHOST="$PWD/tmp/postgres-socket"
    export REDIS_URL="redis://localhost:6379/0"
    export GEM_HOME="$PWD/.gems"
    export GEM_PATH="$GEM_HOME"
    export PATH="$GEM_HOME/bin:$PATH"

    echo "LLM CLIs available:"
    if command -v claude &> /dev/null; then
      echo "  ✓ claude"
    else
      echo "  ✗ claude (not found in PATH)"
    fi
    if command -v codex &> /dev/null; then
      echo "  ✓ codex"
    else
      echo "  ✗ codex"
    fi
    if command -v npx &> /dev/null; then
      echo "  ✓ gemini (via npx @google/gemini-cli)"
    else
      echo "  ✗ gemini"
    fi
    echo ""

    # PostgreSQL helper functions
    function pg_start() {
      mkdir -p "$PWD/tmp/postgres-socket"
      if [ -d "$PGDATA" ]; then
        pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" -o "-k $PWD/tmp/postgres-socket" start
        echo "PostgreSQL started (socket: $PWD/tmp/postgres-socket)"
      else
        echo "Initializing PostgreSQL database..."
        initdb -D "$PGDATA" --no-locale --encoding=UTF8
        pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" -o "-k $PWD/tmp/postgres-socket" start
        echo "PostgreSQL started (socket: $PWD/tmp/postgres-socket)"
      fi
    }

    function pg_stop() {
      pg_ctl -D "$PGDATA" stop
      echo "PostgreSQL stopped"
    }

    function pg_status() {
      pg_ctl -D "$PGDATA" status
    }

    # Redis helper functions
    function redis_start() {
      redis-server --daemonize yes --dir "$PWD/tmp" --dbfilename redis.rdb
      echo "Redis started (daemonized)"
    }

    function redis_stop() {
      redis-cli shutdown
      echo "Redis stopped"
    }

    echo "Helper functions available:"
    echo "  pg_start      - Start PostgreSQL"
    echo "  pg_stop       - Stop PostgreSQL"
    echo "  pg_status     - Check PostgreSQL status"
    echo "  redis_start   - Start Redis"
    echo "  redis_stop    - Stop Redis"
    echo ""
    echo "Quick start:"
    echo "  1. pg_start && redis_start"
    echo "  2. bundle install"
    echo "  3. rails db:create db:migrate"
    echo "  4. rails server"
  '';
}