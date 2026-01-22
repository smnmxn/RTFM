class InvitesController < ApplicationController
  skip_before_action :require_authentication

  def show
    invite = Invite.find_by(token: params[:token])

    if invite.nil?
      redirect_to login_path, alert: "Invalid invite link."
    elsif invite.used?
      redirect_to login_path, alert: "This invite has already been used."
    else
      session[:invite_token] = invite.token
      redirect_to login_path, notice: "Invite accepted! Click below to create your account."
    end
  end
end
