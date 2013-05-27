require 'bundler/capistrano'
require 'capistrano/ext/multistage'

default_run_options[:pty] = true
set :keep_releases, 5
set :application, "CHEF VN"
set :repository,  "git@github.com:dangluan/chefsolo.git"
set :scm, :git
set :rake,  "bundle exec rake"
set :stages, ["staging", "production"]
set :default_stage, "staging"
set :use_sudo,	false
set :deploy_via, :remote_cache
set :rake,  "bundle exec rake"
load 'deploy/assets'

after 'deploy:finalize_update', 'deploy:symlink_share', 'deploy:migrate_database'
after "deploy:update", "deploy:cleanup"


def remote_file_exists?(full_path)
  'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
end

namespace :deploy do
  desc "Zero-downtime restart of Unicorn"  
  task :restart, :roles => :web do
    if remote_file_exists?("#{shared_path}/pids/chefsolo.pid")
      text = capture("cat #{shared_path}/pids/chefsolo.pid")
      run "kill -s QUIT `cat #{shared_path}/pids/chefsolo.pid`" if text.nil? == false
    end
    run "cd #{current_path} ; bundle exec unicorn -c config/unicorn.rb -D -E #{rails_env}"
  end
  
  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    run "cd #{current_path} ; bundle exec unicorn -c config/unicorn.rb -D -E #{rails_env}"
    # run "cd #{current_path}; touch tmp/restart.txt"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    run "kill -s QUIT `cat #{shared_path}/pids/chefsolo.pid`"
  end  
    
  namespace :assets do
    task :precompile do            
      if !(ENV["SKIP_ASSET"] == "true")        
        run_locally "bundle exec rake assets:precompile RAILS_ENV=#{rails_env}"
        run_locally "cd public; tar -zcvf assets.tar.gz assets"
        top.upload "public/assets.tar.gz", "#{shared_path}", :via => :scp
        run "cd #{shared_path}; tar -zxvf assets.tar.gz"
        run_locally "rm public/assets.tar.gz"
        run_locally "rm -rf public/assets"
        run "rm -rf #{latest_release}/public/assets"
        run "ln -s #{shared_path}/assets #{latest_release}/public/assets"
        run "rm -rf #{shared_path}/assets.tar.gz"
      end
    end
  end
    
  desc 'migrate database'
  task :migrate_database do
    begin
      run "cd #{release_path} && RAILS_ENV=#{rails_env} #{rake} db:migrate"
    rescue => e
    end
  end
      
  desc 'Symlink share'
  task :symlink_share do
    ## Link System folder 
    run "mkdir -p #{shared_path}/system"
    run "ln -nfs #{shared_path}/system #{release_path}/public/system"
    
    ## Link Database file
    run "rm -f #{release_path}/config/database.yml"    
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"

  end
  
  namespace :web do
    desc "Present a maintenance page to visitors."
    task :disable, :roles => :web, :except => { :no_release => true } do
      require 'erb'
      on_rollback { run "rm #{shared_path}/system/maintenance.html" }

      reason = ENV['REASON']
      deadline = ENV['UNTIL']

      template = File.read("./app/views/layouts/maintenance.html.erb")
      result = ERB.new(template).result(binding)

      put result, "#{shared_path}/system/maintenance.html", :mode => 0644
    end
    
    desc "Disable maintenance mode"
    task :enable, :roles => :web do
      run "rm -f #{shared_path}/system/maintenance.html"
    end
  end
end

