# frozen_string_literal: true

namespace :puma do
  desc 'Reload puma'
  task :reload do
    on roles fetch(:puma_roles) do |role|
      switch_user(role) do
        each_process do |process_name|
          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :systemctl, "reload", process_name, raise_on_non_zero_exit: false
          else
            execute :systemctl, "--user", "reload", process_name, raise_on_non_zero_exit: false
          end
        end
      end
    end
  end

  desc 'Restart puma'
  task :restart do
    on roles fetch(:puma_roles) do |role|
      switch_user(role) do
        each_process do |process_name|
          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :systemctl, 'restart', process_name
          else
            execute :systemctl, '--user', 'restart', process_name
          end
        end
      end
    end
  end

  desc 'Stop puma'
  task :stop do
    on roles fetch(:puma_roles) do |role|
      switch_user(role) do
        each_process do |process_name|
          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :systemctl, "stop", process_name
          else
            execute :systemctl, "--user", "stop", process_name
          end
        end
      end
    end
  end

  desc 'Start puma'
  task :start do
    on roles fetch(:puma_roles) do |role|
      switch_user(role) do
        each_process do |process_name|
          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :systemctl, 'start', process_name
          else
            execute :systemctl, '--user', 'start', process_name
          end
        end
      end
    end
  end

  desc 'Install puma service'
  task :install do
    on roles fetch(:puma_roles) do |role|
      switch_user(role) do
        each_process do |process_name|
          create_config_template(process_name)
          create_systemd_template(process_name)

          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :systemctl, "enable", process_name
          else
            execute :systemctl, "--user", "enable", process_name
            execute :loginctl, "enable-linger", fetch(:puma_lingering_user) if fetch(:puma_enable_lingering)
          end
        end
      end
    end
  end

  desc 'Uninstall puma service'
  task :uninstall do
    on roles fetch(:puma_roles) do |role|
      switch_user(role) do
        each_process do |process_name|
          if fetch(:puma_service_unit_user) == :system
            execute :sudo, :systemctl, "disable", process_name
          else
            execute :systemctl, "--user", "disable", process_name
          end

          execute :rm, '-f', File.join(fetch(:service_unit_path, fetch_systemd_unit_path), process_name)
        end
      end
    end
  end

  desc 'Generate systemd locally'
  task :generate_systemd_locally do
    run_locally do
      each_process do |process_name|
        File.write("tmp/#{process_name}.service", compiled_systemd_template(process_name))
      end
    end
  end

  desc 'Generate config locally'
  task :generate_config_locally do
    run_locally do
      each_process do |process_name|
        File.write("tmp/#{process_name}.rb", compiled_config_template(process_name))
      end
    end
  end
end
