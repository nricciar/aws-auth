module AWS

  class Admin < Sinatra::Base

    POST = %{if(!this.title||confirm(this.title+'?')){var f = document.createElement('form'); this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href; f.submit();}return false;}

    set :sessions, :on
    enable :inline_templates

    @@navigation_tabs = [["users","/control/users",true],["profile","/control/profile"],["logout","/control/logout"]]
    @@home_page = "/control/buckets"

    def self.add_tab(name, path, admin_only=false)
      t = [name,path]
      t << admin_only unless admin_only == false
      @@navigation_tabs = [t] + @@navigation_tabs
    end

    def self.tabs
      @@navigation_tabs
    end

    def self.home_page
      @@home_page
    end

    def self.home_page=(val)
      @@home_page = val
    end

    before do
      ActiveRecord::Base.verify_active_connections!
    end

    get '/?' do
      login_required
      redirect @@home_page
    end

    get %r{^/s/(.*)} do
      expires 500, :public
      open(File.join(AWSAuth::Base::ROOT_DIR,'public', params[:captures].first))
    end

    get '/login' do
      r :login, "Login"
    end

    post '/login' do
      @user = AWSAuth::User.find_by_login params[:login]
      if @user
	if @user.password == AWSAuth::Base.hmac_sha1( params[:password], @user.secret )
	  session[:user_id] = @user.id
	  redirect @@home_page
	else
	  @user.errors.add(:password, 'is incorrect')
	end
      else
	@user = AWSAuth::User.new
	@user.errors.add(:login, 'not found')
      end
      r :login, "Login"
    end

    get '/logout' do
      session[:user_id] = nil
      redirect '/control'
    end

    get "/profile/?" do
      login_required
      @usero = @user
      r :profile, "Your Profile"
    end

    post "/profile/?" do
      login_required
      @user.update_attributes(params['user'])
      @usero = @user
      r :profile, "Your Profile"
    end

    get "/users/?" do
      login_required
      only_superusers
      @usero = AWSAuth::User.new
      @users = AWSAuth::User.find :all, :conditions => ['deleted != 1'], :order => 'login'
      r :users, "User List"
    end

    post "/users/?" do
      login_required
      only_superusers
      @usero = AWSAuth::User.new params['user'].merge(:activated_at => Time.now)
      if @usero.valid?
	@usero.save()
	redirect "/control/users"
      else
	@users = AWSAuth::User.find :all, :conditions => ['deleted != 1'], :order => 'login'
        r :users, "User List"
      end
    end

    get "/users/:login/?" do
      login_required
      only_superusers
      @usero = AWSAuth::User.find_by_login params[:login]
      r :profile, @usero.login
    end

    post "/users/:login/?" do
      login_required
      only_superusers
      @usero = AWSAuth::User.find_by_login params[:login]

      # if were not changing passwords remove blank values
      if params['user']['password'].blank? && params['user']['password_confirmation'].blank?
	params['user'].delete('password')
	params['user'].delete('password_confirmation')
      end

      if @usero.update_attributes(params['user'])
        redirect "/control/users/#{@usero.login}"
      else
        r :profile, @usero.login
      end
    end

    post "/users/delete/:login/?" do
      login_required
      only_superusers
      @usero = AWSAuth::User.find_by_login params[:login]
      if @usero.id == @user.id
	# FIXME: notify user they cannot delete themselves
      else
	@usero.destroy
      end
      redirect "/control/users"
    end

    protected
    def login_required
      @user = AWSAuth::User.find(session[:user_id]) unless session[:user_id].nil?
      redirect '/control/login' if @user.nil?
    end

    def r(name, title, layout = :layout)
      @title = title
      haml name, :layout => layout
    end

    def errors_for(model)
      ret = ""
      if model.errors.size > 0
        ret += "<ul class=\"errors\">"
        model.errors.each_full do |error|
          ret += "<li>#{error}</li>"
        end
        ret += "</ul>"
      end
      ret
    end

    def only_superusers
      redirect '/control/login' unless @user.superuser?
    end

  end

end

__END__

@@ layout
%html
  %head
    %title Control Center &raquo; #{@title}
    %script{ :language => "JavaScript", :type => "text/javascript", :src => "/control/s/js/prototype.js" }
    %style{ :type => "text/css" }
      @import '/control/s/css/control.css';
  %body
    %div#page
      - if @user and not @login
        %div.menu
          %ul
            %li
              - for tab in AWS::Admin.tabs
                - if tab[2].nil? || (tab[2] && @user.superuser?)
                  %a{ :href => tab[1] }= tab[0]
      %div#header
        %h1 Control Center
        %h2 #{@title}
      %div#content
        = yield

@@ login
%form.create{ :method => "post" }
  %div.required
    %label{ :for => "login" } User
    %input#login{ :type => "text", :name => "login" }
  %div.required
    %label{ :for => "password" } Password
    %input#password{ :type => "password", :name => "password" }
  %input#loggo{ :type => "submit", :value => "Login", :name => "loggo" }

@@ users
%table
  %thead
    %tr
      %th Login
      %th Activated On
      %th Actions
  %tbody
    - @users.each do |user|
      %tr
        %th
          %a{ :href => "/control/users/#{user.login}" } #{user.login}
        %td #{user.activated_at}
        %td
          %a{ :href => "/control/users/delete/#{user.login}", :onclick => POST, :title => "Delete user #{user.login}" } Delete
%h3 Create a User
%form.create{ :action => "/control/users", :method => "post" }
  = preserve errors_for(@usero)
  %div.required
    %label{ :for => "user[login]" } Login
    %input.large{ :type => "text", :value => @usero.login, :name => "user[login]" }
  %div.required.inline
    %label{ :for => "user[superuser]" } Is a super-admin?
    %input{ :type => "checkbox", :name => "user[superuser]", :value => @usero.superuser }
  %div.required
    %label{ :for => "user[password]" } Password
    %input.fixed{ :type => "password", :name => "user[password]" }
  %div.required
    %label{ :for => "user[password_confirmation]" } Password again
    %input.fixed{ :type => "password", :name => "user[password_confirmation]" }
  %div.required
    %label{ :for => "user[email]" } Email
    %input{ :type => "text", :value => @usero.email, :name => "user[email]" }
  %div.required
    %label{ :for => "user[key]" } Key (must be unique)
    %input.fixed.long{ :type => "text", :value => (@usero.key || AWSAuth::Base.generate_key), :name => "user[key]" }
  %div.required
    %label{ :for => "user[secret]" } Secret
    %input.fixed.long{ :type => "text", :value => (@usero.secret || AWSAuth::Base.generate_secret), :name => "user[secret]" }
  %input.newuser{ :type => "submit", :value => "Create", :name => "newuser" }

@@ profile
%form.create{ :method => "post" }
  = preserve errors_for(@usero)
  - if @user.superuser?
    %div.required.inline
      %label{ :for => "user[superuser]" } Is a super-admin?
      %input{ :type => "hidden", :name => "user[superuser]", :value => 0 }
      %input{ :type => "checkbox", :name => "user[superuser]", :value => 1, :checked => @usero.superuser? }
  %div.required
    %label{ :for => "user[password]" } Password
    %input.fixed{ :type => "password", :name => "user[password]" }
  %div.required
    %label{ :for => "user[password_confirmation]" } Password again
    %input.fixed{ :type => "password", :name => "user[password_confirmation]" }
  %div.required
    %label{ :for => "user[email]" } Email
    %input{ :type => "text", :value => @usero.email, :name => "user[email]" }
  %div.required
    %label{ :for => "key" } Key
    %h4 #{@usero.key}
  %div.required
    %label{ :for => "secret" } Secret
    %h4 #{@usero.secret}
  %input#saveuser{ :type => "submit", :value => "Save", :name => "saveuser" }
