require 'faraday'
require 'json'

class OllamaClient
  class OllamaError < StandardError; end
  class OllamaTimeoutError < OllamaError; end
  class OllamaConnectionError < OllamaError; end

  def initialize
    @base_url = Rails.application.config.ollama.base_url
    @model = Rails.application.config.ollama.model
    @timeout = Rails.application.config.ollama.timeout
    @api_key = Rails.application.config.ollama.api_key
  end

  def generate(prompt, system_prompt: nil)
    # Convert to OpenAI-compatible chat format for Groq
    messages = []
    messages << { role: "system", content: system_prompt } if system_prompt.present?
    messages << { role: "user", content: prompt }
    
    chat(messages)
  end

  def chat(messages)
    payload = {
      model: @model,
      messages: messages,
      stream: false,
      temperature: 0.7,
      top_p: 0.9,
      max_tokens: 1000
    }

    response = connection.post('/openai/v1/chat/completions') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{@api_key}" if @api_key.present?
      req.body = payload.to_json
    end

    handle_response(response)
  end

  private

  def connection
    @connection ||= Faraday.new(url: @base_url) do |conn|
      conn.options.timeout = @timeout
      conn.adapter Faraday.default_adapter
    end
  end

  def handle_response(response)
    case response.status
    when 200
      parsed = JSON.parse(response.body)
      if parsed['error']
        raise OllamaError, "API error: #{parsed['error']['message'] || parsed['error']}"
      end
      # Handle OpenAI-compatible response format
      parsed.dig('choices', 0, 'message', 'content') || parsed['response']
    when 401
      raise OllamaError, "Unauthorized: Check your API key"
    when 404
      raise OllamaError, "Model '#{@model}' not found"
    when 429
      raise OllamaError, "Rate limit exceeded. Please try again later."
    else
      raise OllamaError, "HTTP #{response.status}: #{response.body}"
    end
  rescue Faraday::TimeoutError
    raise OllamaTimeoutError, "Request timed out after #{@timeout} seconds"
  rescue Faraday::ConnectionFailed
    raise OllamaConnectionError, "Cannot connect to API at #{@base_url}"
  rescue JSON::ParserError => e
    raise OllamaError, "Invalid JSON response: #{e.message}"
  end
end