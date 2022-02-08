# frozen_string_literal: true

module Capistrano
  module Systemd
    module Puma
      class Plugin < Capistrano::Plugin
        def set_defaults
          set_if_empty :puma_roles, -> { fetch(:puma_role, :app) }
          set_if_empty :puma_processes, ['puma']
          set_if_empty :puma_env, -> { fetch(:stage) }

          set_if_empty :puma_init_system, :systemd
          set_if_empty :puma_service_unit_user, :user
          set_if_empty :puma_enable_lingering, true
          set_if_empty :puma_lingering_user, nil

          set_if_empty :puma_pids_path, -> { File.join(shared_path, 'tmp', 'pids') }
          set_if_empty :puma_logs_path, -> { File.join(shared_path, 'log') }
          set_if_empty :puma_config_path, -> { File.join(shared_path, 'config') }
        end

        def define_tasks
          eval_rakefile File.expand_path('../tasks/puma.rake', __FILE__)
        end

        def register_hooks
          after 'deploy:check', 'puma:reload'
          after 'deploy:published', 'puma:restart'
        end
      end
    end
  end
end
