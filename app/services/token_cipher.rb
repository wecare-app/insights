module TokenCipher
  module_function

  def encrypt(plain)
    return nil if plain.blank?

    encryptor.encrypt_and_sign(plain)
  end

  def decrypt(ciphertext)
    return nil if ciphertext.blank?

    encryptor.decrypt_and_verify(ciphertext)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def encryptor
    secret = ENV['INSIGHTS_MASTER_KEY'].presence || Rails.application.secret_key_base
    key = ActiveSupport::KeyGenerator.new(secret).generate_key('insights environment token', 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
