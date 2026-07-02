module Insights
  module Sync
    module_function

    def all
      Environment.active.find_each { |environment| environment(environment) }
    end

    def environment(environment)
      client = InternalApiClient.new(environment)

      client.companies.each do |company|
        wecare_id = sanitize_id(company['id'])
        next if wecare_id.blank?

        record = environment.client_companies.find_or_initialize_by(wecare_id: wecare_id)
        record.name = sanitize_name(company['name'])
        record.last_synced_at = Time.current
        record.active = true if record.new_record?
        record.save!
      end
    rescue InternalApiClient::Error => e
      Rails.logger.warn("[insights sync] #{environment.name}: #{e.message}")
    end

    def sanitize_id(value)
      id = value.to_s.strip
      id =~ /\A[a-zA-Z0-9_-]{1,64}\z/ ? id : nil
    end

    def sanitize_name(value)
      value.to_s.strip.first(255)
    end
  end
end
