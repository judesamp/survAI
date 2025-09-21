class ApplicationController < ActionController::Base
  # Authentication disabled for prototype
  # include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
