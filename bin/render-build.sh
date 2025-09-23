#!/usr/bin/env bash
# exit on error
set -o errexit

# Build commands for Render deployment
echo "Starting Render build process..."

# Install dependencies
echo "Installing Ruby gems..."
bundle install

# Install Node.js dependencies if package.json exists
if [ -f "package.json" ]; then
  echo "Installing Node.js packages..."
  npm install
fi

# Precompile assets
echo "Precompiling assets..."
bundle exec rails assets:precompile

# Run database migrations
echo "Running database migrations..."
bundle exec rails db:migrate

# Setup cache, queue, and cable databases
echo "Setting up Rails databases..."
bundle exec rails db:migrate:cache db:migrate:queue db:migrate:cable

# Seed the database
echo "Seeding database..."
bundle exec rails db:seed

echo "Build process completed!"
