require "uri"
require "net/http"

class SubmitAnalyticsEvent < ApplicationJob
  # No default measurement id: the upstream CIViC value was hardcoded to
  # CIViC's own GA property, which a fork must not silently report to. Set
  # GA_MEASUREMENT_ID/GA_API_SECRET to enable analytics for this deployment.
  GA_MEASUREMENT_ID = ENV["GA_MEASUREMENT_ID"]
  GA_API_SECRET = ENV["GA_API_SECRET"]

  ANALYTICS_URL = "https://www.google-analytics.com/mp/collect?api_secret=#{GA_API_SECRET}&measurement_id=#{GA_MEASUREMENT_ID}"
  HEADER = { 'Content-Type': "application/json" }

  def perform(opts = {})
    return if GA_MEASUREMENT_ID.blank? || GA_API_SECRET.blank?

    Net::HTTP.post(URI(ANALYTICS_URL), create_body(opts))
  end

  private
  def create_body(opts)
    raise NotImplementedError.new("Implement in subclass")
  end
end
