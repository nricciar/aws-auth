require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'

namespace :db do
  task :auth_environment do
    ActiveRecord::Base.establish_connection(AWSAuth::Base.config[:auth])
  end

  desc "Migrate the database"
  task(:auth => :auth_environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true

    out_dir = File.dirname(AWSAuth::Base.config[:auth][:database])
    FileUtils.mkdir_p(out_dir) unless File.exists?(out_dir)

    ActiveRecord::Migrator.migrate(File.join(AWSAuth::Base::ROOT_DIR, 'db', 'migrate'), ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    num_users = AWSAuth::User.count || 0
    if num_users == 0
      puts "** No users found, creating the `admin' user with password `#{AWSAuth::Base::DEFAULT_PASSWORD}'"
      user = AWSAuth::User.new :login => "admin", :password => AWSAuth::Base::DEFAULT_PASSWORD,
        :email => "admin@parkplace.net", :key => AWSAuth::Base.generate_key(), :secret => AWSAuth::Base.generate_secret(),
        :activated_at => Time.now, :superuser => 1
      user.save()
    end
  end
end
