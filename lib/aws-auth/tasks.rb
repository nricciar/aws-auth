require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
require File.join(File.dirname(__FILE__), '../aws-auth')

namespace :auth do
  task :environment do
    ActiveRecord::Base.establish_connection(AWSAuth::Base.config[:db])
  end

  desc "Migrate the database"
  task(:migrate => :environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true

    out_dir = File.dirname(AWSAuth::Base.config[:db][:database])
    FileUtils.mkdir_p(out_dir) unless File.exists?(out_dir)

    ActiveRecord::Migrator.migrate(File.join(AWSAuth::Base::ROOT_DIR, 'db', 'migrate'), ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    num_users = AWSAuth::User.count || 0
    if num_users == 0
      puts "** No users found, creating the `admin' user."
      AWSAuth::User.create :login => "admin", :password => AWSAuth::Base::DEFAULT_PASSWORD,
        :email => "admin@parkplace.net", :key => AWSAuth::Base.generate_key(), :secret => AWSAuth::Base.generate_secret(),
        :activated_at => Time.now, :superuser => 1
    end
  end
end
