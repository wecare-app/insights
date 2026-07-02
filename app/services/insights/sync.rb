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

        record = environment.client_companies.find_by(wecare_id: wecare_id)

        # Só empresas ativas no produto (não bloqueadas). Se o monólito não mandar
        # status (versão antiga), trata como ativa para não quebrar.
        unless company_active?(company)
          record&.update(active: false)
          next
        end

        record ||= environment.client_companies.new(wecare_id: wecare_id)
        record.name = sanitize_name(company['name'])
        record.last_synced_at = Time.current
        record.active = true if record.new_record?
        record.save!
      end
    rescue InternalApiClient::Error => e
      Rails.logger.warn("[insights sync] #{environment.name}: #{e.message}")
    end

    def company_active?(company)
      status = company['status'].to_s
      status.blank? || status == 'released'
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
