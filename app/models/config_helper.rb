require 'base64'
require 'encryptor'

# Load and save DynamicContent configuration data
class ConfigHelper
  def initialize(model)
    @model = model
  end

  def load
    data = JSON.load(@model.data)
    unless data.blank?
      encrypted_userid = Base64.decode64(data['url_userid_enc']) unless data['url_userid_enc'].blank?
      encrypted_password = Base64.decode64(data['url_password_enc']) unless data['url_password_enc'].blank?

      begin
        data['url_userid'] = (encrypted_userid.blank? ? "" : Encryptor.decrypt(encrypted_userid))
        data['url_password'] = (encrypted_password.blank? ? "" : Encryptor.decrypt(encrypted_password))
      rescue StandardError => ex
        Rails.logger.error("Unable to decrypt credentials for dynamic content id #{id}: #{ex.message}")
        data['url_userid'] = ''
        data['url_password'] = ''
      end
    end
    @model.config = data
  end

  def store
    data = @model.config.deep_dup
    data['url_userid_enc'] = (data['url_userid'].blank? ? "" : Base64.encode64(Encryptor.encrypt(data['url_userid'])))
    data['url_password_enc'] = (data['url_password'].blank? ? "" : Base64.encode64(Encryptor.encrypt(data['url_password'])))
    data.delete 'url_userid'
    data.delete 'url_password'
    @model.data = JSON.dump(data)
  end
end