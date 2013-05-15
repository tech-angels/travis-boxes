require 'archive/tar/minitar'
require 'json'
require 'travis/boxes'

module Travis
  module Boxes
    module Cli
      class Veewee < Thor
        namespace "travis:base"

        include Cli

        desc 'build', 'Build a base box from a veewee definition(eg. oneiric32.box)'
        method_option :definition, :aliases => '-d', :default => 'oneiric32', :desc => 'Definition to build the base box from (e.g. oneiric32)'
        method_option :upload,     :aliases => '-u', :desc => 'Upload the box'

        def build
          run <<-sh
            veewee vbox build '#{definition} --force'
            vagrant basebox export #{definition}
            mkdir -p boxes
            mv #{definition}.box boxes/#{definition}.box
          sh
        end

        desc 'build_openvz', 'Build a base openvz template from a veewee definition(eg. oneiric32.tar)'
        method_option :definition, :aliases => '-d', :default => 'oneiric32', :desc => 'Definition to build the base box from (e.g. oneiric32)'
        method_option :upload,     :aliases => '-u', :desc => 'Upload the box'

        def build_openvz
          run <<-sh
            veewee openvz build '#{definition}' --force
            veewee openvz export '#{definition}'
            mkdir -p boxes
            mv '#{definition}.tar' 'boxes/#{definition}.tar'
          sh
        end


        desc 'upload', 'Upload a base box'
        method_option :definition, :aliases => '-d', :default => 'oneiric32', :desc => 'Definition of the box to upload (e.g. oneiric32)'

        def upload
          remote = ::Travis::Boxes::Remote.new
          remote.upload("boxes/#{definition}.box", "bases/#{definition}.box")
        end

        desc 'upload_openvz', 'Upload a base openvz box'
        method_option :definition, :aliases => '-d', :default => 'oneiric32', :desc => 'Definition of the box to upload (e.g. oneiric32)'

        def upload_openvz
          remote = ::Travis::Boxes::Remote.new
          remote.upload("boxes/#{definition}.tar", "bases/#{definition}.tar")
        end


        protected

          def vbox
            @vbox ||= Vbox.new('', options)
          end

          def config
            @config ||= ::Travis::Boxes::Config.new
          end

          def definition
            options['definition']
          end
      end
    end
  end
end
