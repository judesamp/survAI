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
    if using_groq?
      # Groq/OpenAI-compatible API
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
    else
      # Ollama API
      payload = {
        model: @model,
        messages: messages,
        stream: false,
        options: {
          temperature: 0.7,
          top_p: 0.9
        }
      }

      response = connection.post('/api/chat') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = payload.to_json
      end
    end

    handle_response(response)
  end

  private

  def using_groq?
    @base_url.include?('groq.com') || @api_key.present?
  end

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
      
      if using_groq?
        # Handle OpenAI-compatible response format (Groq)
        parsed.dig('choices', 0, 'message', 'content')
      else
        # Handle Ollama response format
        parsed.dig('message', 'content') || parsed['response']
      end
    when 401
      raise OllamaError, "Unauthorized: Check your API key"
    when 404
      if using_groq?
        raise OllamaError, "Model '#{@model}' not found on Groq"
      else
        raise OllamaError, "Model '#{@model}' not found. Install with: ollama pull #{@model}"
      end
    when 429
      raise OllamaError, "Rate limit exceeded. Please try again later."
    else
      raise OllamaError, "HTTP #{response.status}: #{response.body}"
    end
  rescue Faraday::TimeoutError
    raise OllamaTimeoutError, "Request timed out after #{@timeout} seconds"
  rescue Faraday::ConnectionFailed
    if using_groq?
      raise OllamaConnectionError, "Cannot connect to Groq API at #{@base_url}"
    else
      raise OllamaConnectionError, "Cannot connect to Ollama at #{@base_url}. Make sure Ollama is running."
    end
  rescue JSON::ParserError => e
    raise OllamaError, "Invalid JSON response: #{e.message}"
  end
end