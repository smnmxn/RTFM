class PagesController < ApplicationController
  skip_before_action :require_authentication
  layout "legal"

  def how_it_works
    @nav_active = "how-it-works"
  end

  def brand
  end
end
