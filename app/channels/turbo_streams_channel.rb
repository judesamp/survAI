class TurboStreamsChannel < ApplicationCable::Channel
  def subscribed
    stream_name = verified_stream_name_from_params
    if stream_name
      stream_from stream_name
      Rails.logger.info "TurboStreamsChannel: Subscribed to #{stream_name}"
    else
      Rails.logger.error "TurboStreamsChannel: No valid stream name provided"
      reject
    end
  end

  private

  def verified_stream_name_from_params
    # Accept the stream name directly from params
    # In production, you'd want to verify the user can access this stream
    stream_name = params[:signed_stream_name] || params[:stream_name]
    Rails.logger.info "TurboStreamsChannel: Stream name from params: #{stream_name}"
    stream_name
  end
end