require 'archive/tar/minitar'
require 'json'
require 'travis/boxes'

module Travis
  module Boxes
    module Cli
      class Openvz < Thor
        namespace "travis:openvzbox"

        include Cli

        desc 'build [BOX]', 'Build a base box (defaults to development)'
        method_option :base,   :aliases => '-b', :desc => 'Base template for this box (e.g. precise64_base)'
        method_option :upload, :aliases => '-u', :desc => 'Upload the box'
        method_option :download,  :aliases => '-d', :type => :boolean, :default => false, :desc => 'Force base image to be redownloaded'
        def build(box = 'development')
          self.box = box
          puts "Using the '#{box}' image"

          download if options['download']
          add_box
          exit unless up

          package_box
          upload(box) if upload?
        end

        desc 'upload', 'Upload a base box (defaults to development)'
        def upload(box = 'development')
          self.box = box
          cached_timestamp = timestamp

          original    = "openvz-templates/travis-#{box}.tar.gz"
          destination = "provisioned/#{box}/#{cached_timestamp}.tar.gz"

          remote = ::Travis::Boxes::Remote.new
          remote.upload(original, destination)
          remote.symlink(destination, "provisioned/travis-#{box}.tar.gz")
        end

        protected

          attr_accessor :box

          def config
            @config ||= ::Travis::Boxes::Config.new[box]
          end

          def upload?
            options['upload']
          end

          def base
            @base ||= (calculate_base_url(options['base']) || config.base)
          end

          def calculate_base_url(input)
            if input
              if (s = input.downcase).start_with?("http")
                s
              else
                "http://files.travis-ci.org/openvz-templates/bases/#{s}.tar.gz"
              end
            else
              nil
            end
          end

          def target
            @target ||= "openvz-templates/#{base_box_name}.tar.gz"
          end

          def download
            run "mkdir -p openvz-templates"
            # make sure that openvz-templates/travis-*.tar.gz in the end is a new downloaded template,
            # not some old box that will cause wget to append .1 to the name of new file. MK.
            run "rm -rf #{base_name_and_path}"
            run "wget #{base} -P openvz-templates" unless File.exists?(base_name_and_path)
          end

          def add_box
            begin
              File.delete(File.join('/var/lib/vz/template/cache', base_box_name.to_s + '.tar.gz') 
            rescue ::Errno::ENOENT => e
            end
            FileUtils.cp(base_name_and_path, File.join('/var/lib/vz/template/cache', base_box_name.to_s + '.tar.gz')
          end

          def up
            halt
            system('sudo vzctl start ' + base_box_name)
            # TODO: run chef for provisioning
          end

          def halt
            system('sudo vzctl stop ' + base_box_name)
          end

          def package_box
            halt
            system('sudo vzctl dump ' + base_box_name)
            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.mv('/var/lib/vz/dump/Dump.' + veid, target)
          end

          def veid
            result = `sudo vzlist -aH log-1 -oveid`.strip
            raise("could not find #{base_box_name} veid in #{meta.inspect}") unless result =~ /\A[0-9]+\Z/
            result
          end

          def base_box_name
            "travis-#{box}"
          end

          def base_name_and_path
            "openvz-templates/#{File.basename(base)}"
          end

          def timestamp
            Time.now.strftime('%Y-%m-%d-%H%M')
          end
      end
    end
  end
end
