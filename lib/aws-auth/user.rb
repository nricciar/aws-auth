module AWSAuth
class User < ActiveRecord::Base

  establish_connection AWSAuth::Base.config[:auth]

  validates_length_of :login, :within => 3..40
  validates_uniqueness_of :login
  validates_uniqueness_of :key
  validates_presence_of :password
  validates_confirmation_of :password

  before_save :update_user
  after_save :update_password_field

  def destroy
    self.deleted = 1
    self.save
  end

  attr_accessor :skip_before_save

  protected
  def update_user
    unless self.skip_before_save
      @password_clean = self.password
      self.password = AWSAuth::Base.hmac_sha1(self.password, self.secret)
    end
  end

  def update_password_field
    self.password = @password_clean
  end

end
end
