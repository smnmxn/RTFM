Pay.setup do |config|
  config.business_name = "SupportPages"
  config.application_name = "SupportPages"
  config.support_email = "hello@supportpages.io"
  config.enabled_processors = [:stripe]
  config.default_product_name = "SupportPages Pro"
  config.default_plan_name = "pro"
end
