class PagesController < ApplicationController
  include Trackable

  skip_before_action :require_authentication
  layout "legal"

  def how_it_works
    @nav_active = "how-it-works"
  end

  def pricing
    @nav_active = "pricing"
  end

  def features
    redirect_to root_path
  end

  def brand
  end
end
