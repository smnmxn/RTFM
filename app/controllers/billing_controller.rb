class BillingController < ApplicationController
  def show
    @user = current_user
    @subscription = @user.active_subscription
    @project_count = @user.projects.where(onboarding_step: nil).count
    @article_count = Article.where(project_id: @user.project_ids).count
    @team_member_count = 1
  end

  def checkout
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
      cancel_url: billing_url
    }

    # Add trial for users who haven't had one before
    if current_user.free? && current_user.trial_ends_at.nil?
      checkout_options[:subscription_data] = { trial_period_days: 14 }
    end

    checkout_session = current_user.payment_processor.checkout(**checkout_options)
    redirect_to checkout_session.url, allow_other_host: true
  end

  def success
    # Post-checkout confirmation — plan sync happens via webhook
    if current_user.projects.where(onboarding_step: nil).empty?
      redirect_to new_onboarding_project_path, notice: "Pro trial started! Let's set up your first project."
    end
  end

  def portal
    portal_session = current_user.payment_processor.billing_portal(return_url: billing_url)
    redirect_to portal_session.url, allow_other_host: true
  end

end
