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
  end

  def generate(prompt, system_prompt: nil)
    payload = {
      model: @model,
      prompt: prompt,
      stream: false,
      options: {
        temperature: 0.7,
        top_p: 0.9
      }
    }

    payload[:system] = system_prompt if system_prompt.present?

    response = connection.post('/api/generate') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = payload.to_json
    end

    handle_response(response)
  end

  def chat(messages)
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
        raise OllamaError, "Ollama error: #{parsed['error']}"
      end
      parsed['response'] || parsed.dig('message', 'content')
    when 404
      raise OllamaError, "Model '#{@model}' not found. Make sure it's installed with: ollama pull #{@model}"
    else
      raise OllamaError, "HTTP #{response.status}: #{response.body}"
    end
  rescue Faraday::TimeoutError
    raise OllamaTimeoutError, "Ollama request timed out after #{@timeout} seconds"
  rescue Faraday::ConnectionFailed
    raise OllamaConnectionError, "Cannot connect to Ollama at #{@base_url}. Make sure Ollama is running."
  rescue JSON::ParserError => e
    raise OllamaError, "Invalid JSON response from Ollama: #{e.message}"
  end
end