require 'rubygems'
require 'rack'
require 'activerecord'
require 'base64'
require 'digest/sha1'
require 'openssl'
require 'sinatra'
require File.join(File.dirname(__FILE__),'aws-auth/user')
require File.join(File.dirname(__FILE__),'aws-auth/admin')

module AWSAuth
class Base

  VERSION = "0.9.0"
  ROOT_DIR = ENV['AWS_ROOT_DIR'] || File.join(File.dirname(__FILE__),'..')
  DEFAULT_PASSWORD = "testp@ss"

  def self.config
    @@config ||= load_config()
  end

  def initialize(app,config_path=nil)
    @@config_path = config_path
    @app = app
    ActiveRecord::Base.establish_connection(AWSAuth::Base.config[:db])
  end

  def call(env)
    date_s = env['HTTP_X_AMZ_DATE'] || env['HTTP_DATE']

    if env['HTTP_X_AMZN_AUTHORIZATION'] =~ /^AWS3-HTTPS AWSAccessKeyId=(.*),Algorithm=HmacSHA256,Signature=(.*)$/
      access_key = $1
      signature = $2
      user = AWSAuth::User.find_by_key(access_key)
      unless user.nil?
        hmac = HMAC::SHA256.new(user.secret)
        hmac.update(date_s)
        if Base64.encode64(hmac.digest).chomp == signature
          env['AWS_AUTH_USER'] = user
        end
      end
    elsif env['HTTP_AUTHORIZATION'] =~ /^AWS (\w+):(.+)$/
      meta, amz = {}, {}
      env.each do |k,v|
        k = k.downcase.gsub('_', '-')
        amz[$1] = v.strip if k =~ /^http-x-amz-([-\w]+)$/
        meta[$1] = v if k =~ /^http-x-amz-meta-([-\w]+)$/
      end

      auth, key_s, secret_s = *env['HTTP_AUTHORIZATION'].to_s.match(/^AWS (\w+):(.+)$/)
      if request.params.has_key?('Signature') and Time.at(request['Expires'].to_i) >= Time.now
        key_s, secret_s, date_s = request['AWSAccessKeyId'], request['Signature'], request['Expires']
      end
      uri = env['PATH_INFO']
      uri += "?" + env['QUERY_STRING'] if %w[acl versioning torrent].include?(env['QUERY_STRING'])
      canonical = [env['REQUEST_METHOD'], env['HTTP_CONTENT_MD5'], env['CONTENT_TYPE'],
	date_s, uri]
      amz.sort.each do |k, v|
        canonical[-1,0] = "x-amz-#{k}:#{v}"
      end

      user = AWSAuth::User.find_by_key key_s
      unless (user and secret_s != AWSAuth::Base.hmac_sha1(user.secret, canonical.map{|v|v.to_s.strip} * "\n")) || (user and user.deleted == 1)
        env['AWS_AUTH_USER'] = user
      end
    end

    @app.call(env)
  end

  def self.generate_secret
    abc = %{ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz}
    (1..40).map { abc[rand(abc.size),1] }.join
  end

  def self.generate_key
    abc = %{ABCDEF0123456789}
    (1..20).map { abc[rand(abc.size),1] }.join
  end

  def self.hmac_sha1(key, s)
    ipad = [].fill(0x36, 0, 64)
    opad = [].fill(0x5C, 0, 64)
    key = key.unpack("C*")
    if key.length < 64 then
      key += [].fill(0, 0, 64-key.length)
    end

    inner = []
    64.times { |i| inner.push(key[i] ^ ipad[i]) }
    inner += s.unpack("C*")

    outer = []
    64.times { |i| outer.push(key[i] ^ opad[i]) }
    outer = outer.pack("c*")
    outer += Digest::SHA1.digest(inner.pack("c*"))

    return Base64::encode64(Digest::SHA1.digest(outer)).chomp
  end

  protected
  def self.load_config()
    return YAML::load(File.read(ENV['AWS_AUTH_PATH'])) if ENV['AWS_AUTH_PATH'] && File.exists?(ENV['AWS_AUTH_PATH'])
    return YAML::load(File.read(File.expand_path("~/.aws-auth.yml"))) if File.exists?(File.expand_path("~/.aws-auth.yml"))
    return YAML::load(File.read(@@config_path)) if @@config_path && File.exists?(@@config_path)
    return YAML::load(File.read(File.join(File.dirname(__FILE__), '../aws-auth.yml'))) if File.exists?(File.join(File.dirname(__FILE__), '../aws-auth.yml'))
  end

end
end
