# 🚀 Hackathon Deployment Guide

## Quick Deploy to Railway (Recommended for Hackathons)

Railway is the easiest way to deploy your Rails app for a hackathon. It automatically handles PostgreSQL, Redis, and deployment.

### Step 1: Prepare Your Code

1. **Commit all your changes:**
   ```bash
   git add .
   git commit -m "Prepare for deployment"
   ```

2. **Push to GitHub:**
   ```bash
   git push origin main
   ```

### Step 2: Deploy to Railway

1. **Go to [Railway.app](https://railway.app)** and sign up/login
2. **Click "New Project"** → **"Deploy from GitHub repo"**
3. **Select your survAI repository**
4. **Railway will automatically detect it's a Rails app**

### Step 3: Add Services

Railway will automatically add:
- ✅ **Web Service** (your Rails app)
- ✅ **PostgreSQL Database**
- ✅ **Redis** (for caching and background jobs)

### Step 4: Configure Environment Variables

In Railway dashboard, go to your **Web Service** → **Variables** and add:

```bash
# Required
RAILS_ENV=production
RAILS_MASTER_KEY=your_master_key_here
SECRET_KEY_BASE=your_secret_key_base_here

# Database (automatically set by Railway)
DATABASE_URL=postgresql://...

# Redis (automatically set by Railway)  
REDIS_URL=redis://...

# Optional: Ollama (if you want AI features)
OLLAMA_MODEL=llama3.2:3b
OLLAMA_URL=http://your-ollama-instance:11434
```

### Step 5: Get Your Master Key

1. **Copy your master key:**
   ```bash
   cat config/master.key
   ```

2. **Add it to Railway environment variables as `RAILS_MASTER_KEY`**

### Step 6: Deploy!

1. **Railway will automatically build and deploy your app**
2. **Database migrations will run automatically** (thanks to the Procfile)
3. **Your app will be live at a Railway URL like: `https://your-app-name.railway.app`**

---

## Alternative: Render.com

If Railway doesn't work, try Render:

1. **Go to [Render.com](https://render.com)**
2. **New Web Service** → **Connect GitHub**
3. **Select your repo**
4. **Configure:**
   - **Build Command:** `bundle install && bundle exec rails assets:precompile`
   - **Start Command:** `bundle exec rails server -b 0.0.0.0 -p $PORT`
5. **Add PostgreSQL and Redis services**
6. **Set environment variables**

---

## Alternative: Heroku

1. **Install Heroku CLI**
2. **Login:** `heroku login`
3. **Create app:** `heroku create your-app-name`
4. **Add PostgreSQL:** `heroku addons:create heroku-postgresql:mini`
5. **Add Redis:** `heroku addons:create heroku-redis:mini`
6. **Set config:** `heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)`
7. **Deploy:** `git push heroku main`

---

## Testing Your Deployment

1. **Visit your deployed URL**
2. **Create a test survey**
3. **Generate some test data**
4. **Check the dashboard works**

## Troubleshooting

### Common Issues:

**Database connection errors:**
- Make sure `DATABASE_URL` is set correctly
- Check that migrations ran successfully

**Asset compilation errors:**
- Make sure `SECRET_KEY_BASE` is set
- Check that all gems are in the Gemfile

**Ollama/AI features not working:**
- This is expected in production without Ollama
- The app will fall back to template responses

### Quick Fixes:

```bash
# Check logs
railway logs

# Restart service
railway restart

# Run migrations manually
railway run rails db:migrate
```

---

## 🎯 Hackathon Tips

1. **Deploy early** - Don't wait until the last minute
2. **Test thoroughly** - Make sure core features work
3. **Have a backup plan** - Railway, Render, and Heroku are all good options
4. **Document your demo** - Prepare a quick walkthrough of key features
5. **Monitor performance** - Check that the app loads quickly

Your app should be live and ready for hackathon participants to use! 🚀
