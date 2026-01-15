# frozen_string_literal: true

# Configure Pry for a better Rails console experience
if defined?(Pry)
  # Use AmazingPrint for pretty output
  require "amazing_print"
  AmazingPrint.pry!

  # Customize the prompt to show the app name and environment
  Pry.config.prompt = Pry::Prompt.new(
    "rtfm",
    "Custom prompt with app name",
    [
      proc { |obj, nest_level, _| "rtfm(#{Rails.env})> " },
      proc { |obj, nest_level, _| "rtfm(#{Rails.env})* " }
    ]
  )
end
