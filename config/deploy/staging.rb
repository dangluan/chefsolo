server "192.168.2.150", :app, :web, :db, :primary => true
set :rails_env, "staging"
set :user, 'rubyviet'
set :branch, :master
set :deploy_to, "/home/rubyviet/www/chefsolo"
# set :port, 3790

default_run_options[:pty] = true
set :default_environment, {
  'PATH' => "/home/rubyviet/.rbenv/shims:/home/rubyviet/.rbenv/bin:$PATH"
}