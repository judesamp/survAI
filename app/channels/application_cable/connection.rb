module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # For prototype - allow connections without authentication
      self.current_user = get_or_create_default_user
    end

    private
      def get_or_create_default_user
        # Use the same default user logic as in surveys controller
        organization = Organization.first_or_create!(
          name: "Default Organization",
          slug: "default-org",
          plan: "free"
        )

        User.first || User.create!(
          email_address: "admin@survai.com",
          first_name: "Admin",
          last_name: "User",
          organization: organization,
          role: "admin"
        )
      end
  end
end
