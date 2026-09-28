# Docker-friendly Puma config: binds TCP via PORT/-p rather than the Capistrano
# deploy's unix socket + hardcoded /var/www/civic/current directory (which
# doesn't exist in a container and crashed boot with Dir.chdir ENOENT).
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV") { "headless" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Specifies the number of `workers` to boot in clustered mode.
#
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use the `preload_app!` method when specifying a `workers` number.
#
preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart
