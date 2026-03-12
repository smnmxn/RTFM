class PlansController < ApplicationController
  layout "onboarding"

  def show
    # Only for new users with no completed projects
    if current_user.projects.where(onboarding_step: nil).any?
      redirect_to projects_path
      return
    end

    @selected_plan = session[:selected_plan] || "pro"
  end

  def create
    if params[:plan] == "free"
      session.delete(:selected_plan)
      redirect_to new_onboarding_project_path
    elsif params[:plan] == "pro"
      session.delete(:selected_plan)

      interval = params[:interval] == "monthly" ? "monthly" : "annual"

      price_id = if interval == "monthly"
        ENV.fetch("STRIPE_PRO_MONTHLY_PRICE_ID")
      else
        ENV.fetch("STRIPE_PRO_ANNUAL_PRICE_ID")
      end

      checkout_options = {
        mode: "subscription",
        line_items: [{ price: price_id, quantity: 1 }],
        success_url: success_billing_url,
        cancel_url: choose_plan_url
      }

      if current_user.free? && current_user.trial_ends_at.nil?
        checkout_options[:subscription_data] = { trial_period_days: 14 }
      end

      checkout_session = current_user.payment_processor.checkout(**checkout_options)
      redirect_to checkout_session.url, allow_other_host: true
    else
      redirect_to choose_plan_path
    end
  end
end
