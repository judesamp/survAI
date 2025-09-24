class SurveyDataGenerationJob < ApplicationJob
  queue_as :default

  def perform(survey_id, assignments_count, responses_count, job_id)
    survey = Survey.find(survey_id)
    Rails.logger.info "[JOB #{job_id}] Starting data generation for survey #{survey_id}"

    # Calculate total expected items (assignments + responses)
    total_items = assignments_count + responses_count
    items_completed = 0

    # Broadcast start message with total context
    broadcast_progress_with_counts(survey, "Starting data generation...", 0, job_id, 0, total_items)
    sleep(0.5) # Give time for initial broadcast to render

    begin
      generator = SurveyDataGenerator.new(survey)

      # Step 1: Create assignments
      Rails.logger.info "[JOB #{job_id}] Creating #{assignments_count} assignments"
      broadcast_progress_with_counts(survey, "Creating assignments...", 10, job_id, 0, total_items)
      sleep(0.2)

      assignments = generator.create_assignments(assignments_count)
      items_completed = assignments.count
      Rails.logger.info "[JOB #{job_id}] Created #{assignments.count} assignments"

      # Calculate progress based on assignments created
      progress = (items_completed.to_f / total_items * 100).to_i
      broadcast_progress_with_counts(survey, "Created #{assignments.count} assignments", progress, job_id, items_completed, total_items)
      # Dashboard will refresh automatically via Assignment model callbacks
      sleep(0.2)

      # Step 2: Generate responses
      Rails.logger.info "[JOB #{job_id}] Generating #{responses_count} responses"
      broadcast_progress_with_counts(survey, "Generating responses...", progress, job_id, items_completed, total_items)
      sleep(0.2)

      created_responses = []
      assignments_for_responses = assignments.sample(responses_count)

      assignments_for_responses.each_with_index do |assignment, index|
        response = generator.create_response_for_assignment(assignment)
        created_responses << response if response

        # Update items completed
        items_completed = assignments_count + (index + 1)

        # Calculate real progress based on total items
        progress = (items_completed.to_f / total_items * 100).to_i
        message = "Generated #{index + 1}/#{responses_count} responses"
        Rails.logger.info "[JOB #{job_id}] Progress: #{progress}% - #{message}"
        broadcast_progress_with_counts(survey, message, progress, job_id, items_completed, total_items)

        # Dashboard will refresh automatically via Response model callbacks

        # Small delay to see progress
        sleep(0.2)
      end

      Rails.logger.info "[JOB #{job_id}] Finalizing"
      broadcast_progress_with_counts(survey, "Finalizing...", 95, job_id, items_completed, total_items)
      sleep(0.2)

      result = {
        assignments_created: assignments.count,
        responses_created: created_responses.count
      }

      Rails.logger.info "[JOB #{job_id}] Completed - Created #{assignments.count} assignments and #{created_responses.count} responses"
      # Broadcast completion with results
      broadcast_completion(survey, result, job_id)

    rescue => e
      Rails.logger.error "Data generation failed: #{e.message}"
      broadcast_error(survey, e.message, job_id)
    end
  end

  private

  def broadcast_progress_with_counts(survey, message, percentage, job_id, current_count, total_count)
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.info "[BROADCAST] Sending to #{stream_name}: #{message} (#{percentage}% - #{current_count}/#{total_count})"

    # Add a timestamp to force DOM updates
    html_content = render_progress_html_with_counts(message, percentage, job_id, current_count, total_count)

    # Use broadcast_replace_to to ensure the element is fully replaced
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "data-generation-status",
      html: html_content
    )

    Rails.logger.info "[BROADCAST] Sent to #{stream_name} - #{percentage}% complete"
  end

  def broadcast_progress(survey, message, percentage, job_id)
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.info "[BROADCAST] Sending to #{stream_name}: #{message} (#{percentage}%)"

    # Add a timestamp to force DOM updates
    html_content = render_progress_html(message, percentage, job_id)

    # Use broadcast_replace_to to ensure the element is fully replaced
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "data-generation-status",
      html: html_content
    )

    Rails.logger.info "[BROADCAST] Sent to #{stream_name} - #{percentage}% complete"
  end

  def broadcast_completion(survey, result, job_id)
    # Reload survey data for fresh counts
    survey.reload
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.info "Broadcasting completion to #{stream_name}"

    # Broadcast completion status using html to avoid template wrapper
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "data-generation-status",
      html: render_completion_html(result, job_id)
    )

    # Dashboard already refreshed via model callbacks, no need to refresh again
  end

  def broadcast_error(survey, error_message, job_id)
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.error "Broadcasting error to #{stream_name}: #{error_message}"

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "data-generation-status",
      html: render_error_html(error_message, job_id)
    )
  end

  def broadcast_response_created(survey, response, current_count, total_count, job_id)
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.info "Broadcasting response created to #{stream_name}: #{current_count}/#{total_count}"

    # Add a response notification above the progress bar
    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name,
      target: "data-generation-status",
      content: render_response_html(response, current_count, total_count)
    )
  end

  # This method is no longer needed as dashboard refreshes are handled by model callbacks
  # Keeping it commented for reference
  # def refresh_dashboard_content(survey)
  #   # Reload survey with associations
  #   survey.reload
  #   assignments = survey.assignments.includes(:user, :response)
  #   questions = survey.questions.includes(:answers)
  #
  #   # Calculate fresh metrics
  #   metrics = {
  #     response_rate: survey.response_rate,
  #     completion_rate: survey.completion_rate,
  #     average_completion_time: survey.average_completion_time,
  #     average_scale_score: survey.average_scale_score,
  #     assignments_by_status: survey.assignments_by_status
  #   }
  #
  #   # Render the dashboard content partial
  #   renderer = ApplicationController.renderer.new
  #   html = renderer.render(
  #     partial: 'surveys/dashboard_content',
  #     locals: {
  #       survey: survey,
  #       assignments: assignments,
  #       questions: questions,
  #       metrics: metrics
  #     }
  #   )
  #
  #   # Broadcast the updated dashboard content
  #   stream_name = "survey_#{survey.id}_data_generation"
  #   Rails.logger.info "[BROADCAST] Refreshing dashboard content for #{stream_name}"
  #
  #   Turbo::StreamsChannel.broadcast_replace_to(
  #     stream_name,
  #     target: "dashboard-content",
  #     html: html
  #   )
  # end

  def calculate_metrics(survey)
    assignments = survey.assignments.includes(:user, :response)
    {
      response_rate: survey.response_rate,
      completion_rate: survey.completion_rate,
      average_completion_time: survey.average_completion_time,
      average_scale_score: survey.average_scale_score,
      assignments_by_status: survey.assignments_by_status
    }
  end

  def render_progress_html_with_counts(message, percentage, job_id, current_count, total_count)
    # Generate a unique ID for each update to force re-rendering
    update_id = SecureRandom.hex(4)
    %{
      <div id="data-generation-status" class="bg-blue-50 border border-blue-200 rounded-lg p-4" data-update-id="#{update_id}" data-percentage="#{percentage}">
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center space-x-3">
            <svg class="animate-spin h-5 w-5 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="text-sm font-medium text-blue-900">#{message}</span>
          </div>
          <div class="flex items-center space-x-3">
            <span class="text-sm text-blue-700">#{current_count}/#{total_count}</span>
            <span class="text-xs text-blue-700 font-medium bg-blue-100 px-2 py-1 rounded">#{percentage}%</span>
          </div>
        </div>
        <div class="w-full bg-blue-200 rounded-full h-2">
          <div class="bg-blue-600 h-2 rounded-full" style="width: #{percentage}%; transition: width 0.3s ease-out;"></div>
        </div>
        <div class="mt-2 text-xs text-blue-600">Job: #{job_id} | Time: #{Time.current.strftime('%H:%M:%S.%L')} | Update: #{update_id}</div>
      </div>
    }
  end

  def render_progress_html(message, percentage, job_id)
    # Generate a unique ID for each update to force re-rendering
    update_id = SecureRandom.hex(4)
    %{
      <div id="data-generation-status" class="bg-blue-50 border border-blue-200 rounded-lg p-4" data-update-id="#{update_id}" data-percentage="#{percentage}">
        <div class="flex items-center justify-between mb-3">
          <svg class="animate-spin h-5 w-5 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm font-medium text-blue-900">#{message}</span>
          <span class="text-xs text-blue-700 font-medium">#{percentage}%</span>
        </div>
        <div class="w-full bg-blue-200 rounded-full h-2">
          <div class="bg-blue-600 h-2 rounded-full" style="width: #{percentage}%; transition: width 0.3s ease-out;"></div>
        </div>
        <div class="mt-2 text-xs text-blue-600">Job: #{job_id} | Time: #{Time.current.strftime('%H:%M:%S.%L')} | Update: #{update_id}</div>
      </div>
    }
  end

  def render_completion_html(result, job_id)
    %{
      <div id="data-generation-status" class="bg-green-50 border border-green-200 rounded-lg p-4">
        <div class="flex items-center">
          <svg class="h-5 w-5 text-green-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
          </svg>
          <div>
            <h3 class="text-sm font-medium text-green-900">Data Generation Complete!</h3>
            <div class="mt-1 text-sm text-green-700">
              Created #{result[:assignments_created]} assignments and #{result[:responses_created]} responses
            </div>
            <div class="mt-1 text-xs text-green-600">Job ID: #{job_id} | Completed: #{Time.current.strftime('%H:%M:%S')}</div>
          </div>
        </div>
      </div>
    }
  end

  def render_error_html(error_message, job_id)
    %{
      <div id="data-generation-status" class="bg-red-50 border border-red-200 rounded-lg p-4">
        <div class="flex items-center">
          <svg class="h-5 w-5 text-red-600 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
          <div>
            <h3 class="text-sm font-medium text-red-900">Data Generation Failed</h3>
            <div class="mt-1 text-sm text-red-700">#{error_message}</div>
            <div class="mt-1 text-xs text-red-600">Job ID: #{job_id} | Failed: #{Time.current.strftime('%H:%M:%S')}</div>
          </div>
        </div>
      </div>
    }
  end

  def render_response_html(response, current_count, total_count)
    %{
      <div class="mb-2 p-2 bg-sky-50 border border-sky-200 rounded text-sm">
        <div class="flex items-center justify-between">
          <span class="text-sky-900">
            ✅ Response #{current_count}/#{total_count} - #{response.user.display_name}
          </span>
          <span class="text-xs text-sky-600">
            #{response.answers.count} answers
          </span>
        </div>
      </div>
    }
  end
end
