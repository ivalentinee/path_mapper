#!/bin/bash
set -e

useradd -m -u 1000 elixir

# Set locale for uid 1000 user
USER_HOME=$(getent passwd 1000 | cut -d: -f6)
for rc in "$USER_HOME/.bashrc" "$USER_HOME/.profile"; do
  echo 'export LANG=en_US.UTF-8' >> "$rc"
  echo 'export LC_ALL=en_US.UTF-8' >> "$rc"
done

# Install hex and rebar for the dev user
su - "$(id -nu 1000)" -c "mix local.hex --force && mix local.rebar --force"
