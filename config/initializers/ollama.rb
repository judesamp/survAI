Rails.application.configure do
  # Ollama configuration
  config.ollama = ActiveSupport::OrderedOptions.new
  config.ollama.base_url = ENV.fetch('OLLAMA_BASE_URL', 'http://host.docker.internal:11434')
  config.ollama.model = ENV.fetch('OLLAMA_MODEL', 'llama3.1:8b')
  config.ollama.timeout = ENV.fetch('OLLAMA_TIMEOUT', '60').to_i
end