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

    echo "Setup instructions:"
    echo "1. Install Rails: gem install rails"
    echo "2. Create Rails app: rails new . --database=postgresql --css=tailwind --skip-test --force"
    echo "3. Run 'bundle install' to install additional gems"
    echo "4. Run 'rails db:create' to create databases"
    echo "5. Run 'rails server' to start the application"
  '';
}