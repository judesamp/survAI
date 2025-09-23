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

# Prepare database (create, migrate, or load schema as needed)
echo "Preparing database..."
bundle exec rails db:prepare

# Seed the database
echo "Seeding database..."
bundle exec rails db:seed

echo "Build process completed!"
