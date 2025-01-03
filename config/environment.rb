# frozen_string_literal: true

# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

# Clear the cache
Cache::CleaningJob.perform_later

# Preheat the cache
Cache::PreheatingJob.perform_later
