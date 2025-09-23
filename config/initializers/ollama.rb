Rails.application.configure do
  # AI service configuration (supports both Ollama and Groq)
  config.ollama = ActiveSupport::OrderedOptions.new
  config.ollama.base_url = ENV.fetch('AI_BASE_URL', ENV.fetch('OLLAMA_BASE_URL', 'https://api.groq.com'))
  config.ollama.model = ENV.fetch('AI_MODEL', ENV.fetch('OLLAMA_MODEL', 'llama-3.1-8b-instant'))
  config.ollama.timeout = ENV.fetch('AI_TIMEOUT', ENV.fetch('OLLAMA_TIMEOUT', '60')).to_i
  config.ollama.api_key = ENV.fetch('AI_API_KEY', ENV.fetch('GROQ_API_KEY', nil))
end