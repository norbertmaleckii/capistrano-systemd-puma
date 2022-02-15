# frozen_string_literal: true

module Capistrano
  module Systemd
    module Puma
      module DSL
        def puma_each_process(role)
          fetch(:puma_processes).select { |k, _v| role.roles.to_a.map(&:to_s).include?("puma-#{k}") }.each do |process_name|
            set(:puma_current_process, process_name)

            yield "puma-#{process_name}"
          end
        end

        def puma_create_config_template(process_name)
          compiled_template = puma_compiled_config_template(process_name)
          tmp_path = "/tmp/#{process_name}.rb"

          upload!(StringIO.new(compiled_template), tmp_path)

          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :mv, tmp_path, fetch_puma_config
          else
            execute :mv, tmp_path, fetch_puma_config
          end
        end

        def puma_compiled_config_template(process_name)
          search_paths = [
            File.expand_path(
                File.join(*%w[.. templates puma.rb.erb]),
                __FILE__
            ),
          ]

          template_path = search_paths.detect { |path| File.file?(path) }
          template = File.read(template_path)

          ERB.new(template).result(binding)
        end

        def puma_create_systemd_template(process_name)
          systemd_path = fetch_puma_systemd_unit_path

          if fetch(:puma_service_unit_user) == :user
            execute :mkdir, "-p", systemd_path
          end

          compiled_template = puma_compiled_systemd_template(process_name)
          tmp_path = "/tmp/#{process_name}.service"

          upload!(StringIO.new(compiled_template), tmp_path)

          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :mv, tmp_path, "#{systemd_path}/#{process_name}.service"
            execute :sudo, :systemctl, "daemon-reload"
          else
            execute :mv, tmp_path, "#{systemd_path}/#{process_name}.service"
            execute :systemctl, "--user", "daemon-reload"
          end
        end

        def puma_compiled_systemd_template(process_name)
          args = []
          args.push "--config #{fetch_puma_config}"
          args.push "--port 3000"

          search_paths = [
            File.expand_path(
                File.join(*%w[.. templates puma.service.erb]),
                __FILE__
            ),
          ]

          template_path = search_paths.detect { |path| File.file?(path) }
          template = File.read(template_path)

          ERB.new(template).result(binding)
        end

        def puma_switch_user(role)
          su_user = puma_user

          if su_user != role.user
            yield
          else
            as su_user do
              yield
            end
          end
        end

        def puma_user
          fetch(:puma_user, fetch(:run_as))
        end

        def fetch_puma_systemd_unit_path
          if fetch(:puma_service_unit_user) == :system
            "/etc/systemd/system/"
          else
            home_dir = capture(:pwd)

            File.join(home_dir, ".config", "systemd", "user")
          end
        end

        def fetch_puma_rackup
          # if fetch(:puma_processes).length > 1
          #   File.join(current_path, 'apps', fetch(:puma_current_process), 'config.ru')
          # else
          #   File.join(current_path, 'config.ru')
          # end

          File.join(current_path, 'apps', fetch(:puma_current_process), 'config.ru')
        end

        def fetch_puma_pid
          File.join(fetch(:puma_pids_path), "#{fetch(:puma_current_process)}.pid")
        end

        def fetch_puma_state
          File.join(fetch(:puma_pids_path), "#{fetch(:puma_current_process)}.state")
        end

        def fetch_puma_access_log
          File.join(fetch(:puma_logs_path), "#{fetch(:puma_current_process)}.access.log")
        end

        def fetch_puma_error_log
          File.join(fetch(:puma_logs_path), "#{fetch(:puma_current_process)}.error.log")
        end

        def fetch_puma_config
          File.join(fetch(:puma_config_path), "#{fetch(:puma_current_process)}.rb")
        end
      end
    end
  end
end

extend Capistrano::Systemd::Puma::DSL

SSHKit::Backend::Local.module_eval do
  include Capistrano::Systemd::Puma::DSL
end

SSHKit::Backend::Netssh.module_eval do
  include Capistrano::Systemd::Puma::DSL
end
