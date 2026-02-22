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

    echo "Setup instructions:"
    echo "1. Install Rails: gem install rails"
    echo "2. Create Rails app: rails new . --database=postgresql --css=tailwind --skip-test --force"
    echo "3. Run 'bundle install' to install additional gems"
    echo "4. Run 'rails db:create' to create databases"
    echo "5. Run 'rails server' to start the application"
  '';
}