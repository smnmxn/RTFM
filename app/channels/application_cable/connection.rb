module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # Allow both authenticated and unauthenticated connections
      # Unauthenticated connections are needed for public Help Centre streaming
      self.current_user = find_user
    end

    private

    def find_user
      User.find_by(id: request.session[:user_id])
      # Returns nil for unauthenticated users, which is fine for public channels
    end
  end
end
