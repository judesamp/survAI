Rails.application.configure do
  # AI service configuration (supports both Ollama and Groq)
  config.ollama = ActiveSupport::OrderedOptions.new

  # Environment-aware defaults
  if Rails.env.production?
    # Production: Default to Groq for reliability
    default_base_url = 'https://api.groq.com'
    default_model = 'llama-3.1-8b-instant'
  else
    # Development: Try local Ollama first, fallback to Groq
    default_base_url = 'http://host.docker.internal:11434'
    default_model = 'llama3.1:8b'
  end

  config.ollama.base_url = ENV.fetch('AI_BASE_URL', ENV.fetch('OLLAMA_BASE_URL', default_base_url))
  config.ollama.model = ENV.fetch('AI_MODEL', ENV.fetch('OLLAMA_MODEL', default_model))
  config.ollama.timeout = ENV.fetch('AI_TIMEOUT', ENV.fetch('OLLAMA_TIMEOUT', '60')).to_i
  config.ollama.api_key = ENV.fetch('AI_API_KEY', ENV.fetch('GROQ_API_KEY', nil))
end