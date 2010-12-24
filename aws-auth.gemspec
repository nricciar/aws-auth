$:.unshift "./lib"
require 'rake'
require 'aws-auth'
require 'aws-auth/tasks'

spec = Gem::Specification.new do |s|
  s.name = "aws-auth"
  s.version = AWSAuth::Base::VERSION
  s.author = "David Ricciardi"
  s.email = "nricciar@gmail.com"
  s.homepage = "http://github.com/nricciar/aws-auth"
  s.platform = Gem::Platform::RUBY
  s.summary = "AWS Style authentication middleware"
  s.files = FileList["{lib,db,public}/**/*"].to_a +
    ["Rakefile","README","aws-auth.yml"]
  s.require_path = "lib"
  s.description = File.read("README")
  s.executables = []
  s.has_rdoc = false
  s.extra_rdoc_files = ["README"]
  s.add_dependency("sinatra")
  s.add_dependency("activerecord")
end
