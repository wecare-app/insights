Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.object_src  :none
  policy.script_src  :self, 'https://cdn.jsdelivr.net'
  # unsafe_inline vale só para estilos; scripts só rodam com o nonce (abaixo).
  policy.style_src   :self, :unsafe_inline, 'https://fonts.googleapis.com', 'https://cdnjs.cloudflare.com'
  policy.connect_src :self
  policy.base_uri    :self
  policy.frame_ancestors :none
end

Rails.application.config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
