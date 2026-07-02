module Insights
  module Sync
    module_function

    # Status que contam como "ativa no produto". 'released' mantém compat com a
    # versão antiga do monólito; a nova manda 'active'/'trial'/'blocked'/'demo'.
    ACTIVE_STATUSES = %w[active released].freeze

    def all
      Environment.active.find_each { |environment| environment(environment) }
    end

    def environment(environment)
      client = InternalApiClient.new(environment)

      client.companies.each do |company|
        wecare_id = sanitize_id(company['id'])
        next if wecare_id.blank?

        status = company['status'].to_s.presence
        active = active_status?(status)

        record = environment.client_companies.find_by(wecare_id: wecare_id)
        next if record.nil? && !active # não cria registro de empresa inativa nova

        record ||= environment.client_companies.new(wecare_id: wecare_id)
        record.name = sanitize_name(company['name'])
        record.status = status
        record.last_synced_at = Time.current
        if !active
          record.active = false
        elsif record.new_record?
          record.active = true
        end
        record.save!
      end
    rescue InternalApiClient::Error => e
      Rails.logger.warn("[insights sync] #{environment.name}: #{e.message}")
    end

    def active_status?(status)
      status.blank? || ACTIVE_STATUSES.include?(status)
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
