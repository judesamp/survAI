# survAI

A Rails application with Docker development environment for quick onboarding.

## 🚀 Quick Start (TL;DR)

```bash
git clone [repository-url] && cd survAI
cp .env.example .env
chmod +x bin/docker-setup bin/docker-dev
bin/docker-setup
docker-compose up
```
→ Open http://localhost:3001

## Tech Stack

- Ruby 3.2.2
- Rails 8.0.2
- PostgreSQL 17
- Redis 7
- Tailwind CSS

## Getting Started on a New Machine

### Prerequisites

Before you begin, ensure you have the following installed on your machine:

- **Docker Desktop** (includes Docker and Docker Compose)
  - [Mac](https://docs.docker.com/desktop/install/mac-install/)
  - [Windows](https://docs.docker.com/desktop/install/windows-install/)
  - [Linux](https://docs.docker.com/desktop/install/linux-install/)
- **Git** for version control
- A code editor (VS Code, RubyMine, etc.)

### Initial Setup (First Time Only)

1. **Clone the repository:**
```bash
git clone [repository-url]
cd survAI
```

2. **Copy environment variables:**
```bash
cp .env.example .env
```
Edit `.env` if you need custom configurations (usually not necessary for development).

3. **Make scripts executable:**
```bash
chmod +x bin/docker-setup bin/docker-dev
```

4. **Run the automated setup:**
```bash
bin/docker-setup
```

This command will automatically:
- ✅ Build all Docker images
- ✅ Start PostgreSQL and Redis services
- ✅ Create development and test databases
- ✅ Run database migrations
- ✅ Seed initial data (if available)

5. **Start the application:**
```bash
docker-compose up
```

The application will be available at http://localhost:3001

### Daily Development Workflow

After initial setup, your daily workflow is simple:

**Start working:**
```bash
docker-compose up
```

**Stop working:**
```bash
docker-compose stop
# or press Ctrl+C if running in foreground
```

**If you pull new changes from git:**
```bash
git pull
docker-compose build  # Rebuild if Gemfile changed
bin/docker-dev migrate  # Run new migrations if any
```

## Development with Docker

### Common Commands

We've included a helper script `bin/docker-dev` for common tasks:

```bash
# Start Rails console
bin/docker-dev console

# Run tests
bin/docker-dev test

# Run migrations
bin/docker-dev migrate

# Generate a model
bin/docker-dev generate model User name:string email:string

# See all available commands
bin/docker-dev
```

### Direct Docker Commands

```bash
# Start all services in background
docker-compose up -d

# View logs
docker-compose logs -f web

# Stop all services
docker-compose stop

# Remove all containers
docker-compose down

# Rebuild images (after Gemfile changes)
docker-compose build
```

### Running Commands in Containers

```bash
# Rails console
docker-compose run --rm web rails console

# Run tests
docker-compose run --rm web rails test

# Bundle install (after adding gems)
docker-compose run --rm web bundle install

# Any Rails command
docker-compose run --rm web rails [command]
```

## Local Development (without Docker)

### Prerequisites

- Ruby 3.2.2
- PostgreSQL 17
- Redis
- Node.js and npm

### Setup

1. Install dependencies:
```bash
bundle install
```

2. Setup database:
```bash
rails db:create
rails db:migrate
```

3. Start the server:
```bash
bin/dev
```

## Testing

```bash
# With Docker
bin/docker-dev test

# Without Docker
rails test
```

## Environment Variables

Copy `.env.example` to `.env` and customize as needed:

```bash
cp .env.example .env
```

## Troubleshooting

### Common Setup Issues on New Machines

**Docker Desktop not starting:**
- Make sure virtualization is enabled in BIOS (for Windows/Linux)
- On Mac, ensure you have enough disk space (at least 10GB free)
- Try restarting your machine after Docker Desktop installation

**Port already in use error:**
```bash
# Check what's using port 3001
lsof -i :3001  # Mac/Linux
netstat -ano | findstr :3001  # Windows

# Or change the port in docker-compose.yml
# Change "3001:3000" to "3002:3000" or another free port
```

**Permission denied on scripts:**
```bash
chmod +x bin/docker-setup bin/docker-dev
```

**Database connection errors:**
```bash
# Reset and recreate everything
docker-compose down -v  # Remove volumes
docker system prune -a  # Clean Docker cache (careful!)
bin/docker-setup  # Run setup again
```

### Docker Issues

If you encounter issues with Docker:

1. Ensure Docker Desktop is running (check system tray/menu bar)
2. Reset everything:
```bash
docker-compose down -v
bin/docker-setup
```

3. Check logs:
```bash
docker-compose logs web  # Web server logs
docker-compose logs db   # Database logs
```

### Database Issues

Reset the database:
```bash
# With Docker
bin/docker-dev reset

# Without Docker (not recommended)
rails db:drop db:create db:migrate
```

### Disk Space Issues

Docker can use significant disk space. To clean up:
```bash
docker system prune  # Remove stopped containers, unused networks
docker volume prune  # Remove unused volumes
docker image prune   # Remove unused images
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests
4. Submit a pull request

## License

[Your license here]