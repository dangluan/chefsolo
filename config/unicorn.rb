working_directory File.join(File.dirname(__FILE__), "../")
pid_file = File.join(File.dirname(__FILE__), "../../../shared/pids/chefsolo.pid")
stderr_path File.join(File.dirname(__FILE__), "../../../shared/log/chefsolo.log")
stdout_path File.join(File.dirname(__FILE__), "../../../shared/log/chefsolo.log")
old_pid = pid_file + '.oldbin'

pid pid_file
listen "/tmp/chefsolo.sock"
worker_processes ENV['RAILS_ENV'] == "production" ? 5 : 1
preload_app true
timeout 500

before_fork do |server, worker|
  
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
  end
    
  # zero downtime deploy magic:
  # if unicorn is already running, ask it to start a new process and quit.
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # already done
    end
  end
end

after_fork do |server, worker|
  # the following is *required* for Rails + "preload_app true",
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end

  # if preload_app is true, then you may also want to check and
  # restart any other shared sockets/descriptors such as Memcached,
  # and Redis.  TokyoCabinet file handles are safe to reuse
  # between any number of forked children (assuming your kernel
  # correctly implements pread()/pwrite() system calls)
end