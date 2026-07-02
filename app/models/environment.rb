require 'resolv'
require 'ipaddr'

class Environment < ApplicationRecord
  has_many :client_companies, dependent: :destroy

  DB_TYPES = %w[dedicated shared].freeze

  validates :name, presence: true, uniqueness: true
  validates :base_url, presence: true
  validates :db_type, inclusion: { in: DB_TYPES }
  validate :base_url_is_safe

  scope :active, -> { where(active: true) }

  def token
    TokenCipher.decrypt(token_ciphertext)
  end

  def token=(value)
    self.token_ciphertext = TokenCipher.encrypt(value)
  end

  # Anti-SSRF: https + host público. Em development http/localhost são liberados.
  def base_url_is_safe
    return if base_url.blank?
    return if Rails.env.development?

    uri = begin
      URI.parse(base_url)
    rescue URI::InvalidURIError
      nil
    end

    unless uri.is_a?(URI::HTTPS) && uri.host.present?
      return errors.add(:base_url, 'deve ser uma URL https válida')
    end

    if private_or_local_host?(uri.host)
      errors.add(:base_url, 'não pode apontar para host interno/privado')
    end
  end

  private

  def private_or_local_host?(host)
    return true if host.casecmp?('localhost')

    addresses = Resolv.getaddresses(host)
    return true if addresses.empty?

    addresses.any? do |addr|
      ip = IPAddr.new(addr)
      ip.loopback? || ip.private? || ip.link_local? ||
        addr.start_with?('169.254.') || addr == '0.0.0.0'
    end
  rescue IPAddr::InvalidAddressError, Resolv::ResolvError
    true
  end
end
