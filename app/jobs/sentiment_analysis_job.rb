class SentimentAnalysisJob < ApplicationJob
  queue_as :default

  def perform(survey_id, job_id)
    survey = Survey.find(survey_id)
    Rails.logger.info "[SENTIMENT JOB #{job_id}] Starting sentiment analysis for survey #{survey_id}"

    # Broadcast start message
    broadcast_progress(survey, "Starting AI sentiment analysis...", 0, job_id)
    sleep(1) # Allow UI to update

    begin
      # Add timeout to prevent infinite hanging
      Timeout::timeout(180) do # 3 minutes max
        analyzer = SurveySentimentAnalyzer.new(survey)

        broadcast_progress(survey, "Analyzing response sentiment...", 20, job_id)
        sleep(1)

        Rails.logger.info "[SENTIMENT JOB #{job_id}] Starting analysis"
        sentiment_data = analyzer.analyze_with_progress(job_id) do |progress, message|
          broadcast_progress(survey, message, progress, job_id)
        end

        broadcast_progress(survey, "Generating insights...", 90, job_id)
        sleep(1)

        # Store the results (you might want to create a SentimentAnalysis model later)
        Rails.cache.write("sentiment_analysis_#{survey.id}", sentiment_data, expires_in: 1.hour)

        broadcast_progress(survey, "Finalizing analysis...", 95, job_id)

        Rails.logger.info "[SENTIMENT JOB #{job_id}] Completed sentiment analysis"

        # Broadcast completion with results
        broadcast_completion(survey, sentiment_data, job_id)
      end

    rescue Timeout::Error
      Rails.logger.error "[SENTIMENT JOB #{job_id}] Sentiment analysis timed out after 3 minutes"
      broadcast_error(survey, "Analysis timed out - too many responses. Please try with fewer responses.", job_id)
    rescue => e
      Rails.logger.error "[SENTIMENT JOB #{job_id}] Sentiment analysis failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      broadcast_error(survey, e.message, job_id)
    end
  end

  private

  def broadcast_progress(survey, message, percentage, job_id)
    stream_name = "survey_#{survey.id}_sentiment_analysis"
    Rails.logger.info "[SENTIMENT BROADCAST] Sending to #{stream_name}: #{message} (#{percentage}%)"

    html_content = render_progress_html(message, percentage, job_id)

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "sentiment-analysis-status",
      html: html_content
    )

    Rails.logger.info "[SENTIMENT BROADCAST] Sent to #{stream_name} - #{percentage}% complete"
  end

  def broadcast_completion(survey, sentiment_data, job_id)
    stream_name = "survey_#{survey.id}_sentiment_analysis"
    Rails.logger.info "[SENTIMENT BROADCAST] Broadcasting completion to #{stream_name}"

    # Broadcast completion status
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "sentiment-analysis-status",
      html: render_completion_html(sentiment_data, job_id)
    )

    # Schedule a page refresh after 3 seconds to show the full results
    Turbo::StreamsChannel.broadcast_append_to(
      stream_name,
      target: "sentiment-analysis-status",
      html: %(<script>setTimeout(() => window.location.href = '/surveys/#{survey.id}/sentiment_analysis', 3000);</script>)
    )
  end

  def broadcast_error(survey, error_message, job_id)
    stream_name = "survey_#{survey.id}_sentiment_analysis"
    Rails.logger.info "[SENTIMENT BROADCAST] Broadcasting error to #{stream_name}: #{error_message}"

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "sentiment-analysis-status",
      html: render_error_html(error_message, job_id)
    )
  end

  def render_progress_html(message, percentage, job_id)
    update_id = SecureRandom.hex(4)
    %{
      <div id="sentiment-analysis-status" class="bg-purple-50 border border-purple-200 rounded-lg p-4" data-update-id="#{update_id}" data-percentage="#{percentage}">
        <div class="flex items-center justify-between mb-3">
          <svg class="animate-spin h-5 w-5 text-purple-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm font-medium text-purple-900">🤖 #{message}</span>
          <span class="text-xs text-purple-700 font-medium">#{percentage}%</span>
        </div>
        <div class="w-full bg-purple-200 rounded-full h-2">
          <div class="bg-purple-600 h-2 rounded-full" style="width: #{percentage}%; transition: width 0.3s ease-out;"></div>
        </div>
        <div class="mt-2 text-xs text-purple-600">Job: #{job_id} | Time: #{Time.current.strftime('%H:%M:%S.%L')} | Update: #{update_id}</div>
      </div>
    }
  end

  def render_completion_html(sentiment_data, job_id)
    overall = sentiment_data[:overall_sentiment]
    priority = sentiment_data[:recommendation_priority]

    %{
      <div id="sentiment-analysis-status" class="bg-green-50 border border-green-200 rounded-lg p-4">
        <div class="flex items-center">
          <svg class="h-5 w-5 text-green-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
          </svg>
          <div>
            <h3 class="text-sm font-medium text-green-900">🎯 Sentiment Analysis Complete!</h3>
            <div class="mt-1 text-sm text-green-700">
              Overall sentiment: #{overall[:label].titleize} (#{(overall[:score] * 100).round}%) | Priority: #{priority.titleize}
            </div>
            <div class="mt-1 text-xs text-green-600">Job ID: #{job_id} | Redirecting to full results...</div>
          </div>
        </div>
      </div>
    }
  end

  def render_error_html(error_message, job_id)
    %{
      <div id="sentiment-analysis-status" class="bg-red-50 border border-red-200 rounded-lg p-4">
        <div class="flex items-center">
          <svg class="h-5 w-5 text-red-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
          <div>
            <h3 class="text-sm font-medium text-red-900">Sentiment Analysis Failed</h3>
            <div class="mt-1 text-sm text-red-700">#{error_message}</div>
            <div class="mt-1 text-xs text-red-600">Job ID: #{job_id} | Failed: #{Time.current.strftime('%H:%M:%S')}</div>
          </div>
        </div>
      </div>
    }
  end
end