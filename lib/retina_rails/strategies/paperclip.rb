module RetinaRails
  module Strategies
    module Paperclip

      module Extensions

        ## Insert :retina interpolation in url or path
        def self.optimize_path(path)
          path.scan(':retina').empty? ? path.gsub(':filename', ':basename.:extension').split('.').insert(-2, ':retina.').join : path
        end

        def self.override_default_options

          ## Remove _retina from style so it doesn't end up in filename
          ::Paperclip.interpolates :style do |attachment, style|
            style.to_s.end_with?('_retina') ? style.to_s[0..-8] : style
          end

          ## Replace :retina with @2x if style ends with _retina
          ::Paperclip.interpolates :retina do |attachment, style|
            style.to_s.end_with?('_retina') ? '@2x' : ''
          end

          ## Make default url compatible with retina optimzer
          url = ::Paperclip::Attachment.default_options[:url]
          ::Paperclip::Attachment.default_options[:url] = optimize_path(url)

        end

      end

      extend ActiveSupport::Concern

      included do

        ## Override paperclip default options
        Extensions.override_default_options

        ## Iterate over each has_attached_file
        attachment_definitions.each_pair do |key, value|

          ## Check for style definitions
          styles = attachment_definitions[key][:styles]

          ## Get retina quality
          retina_quality = attachment_definitions[key][:retina_quality] || 40

          if styles

            retina_styles = {}
            retina_convert_options = {}
            convert_options = attachment_definitions[key][:convert_options]

            ## Iterate over styles and set optimzed dimensions
            styles.each_pair do |key, value|

              dimensions = value[0]

              width  = dimensions.scan(/\d+/)[0].to_i * 2
              height = dimensions.scan(/\d+/)[1].to_i * 2

              processor = dimensions.scan(/#|</).first

              retina_styles["#{key}_retina".to_sym] = ["#{width}x#{height}#{processor}", value[1]]

              ## Set quality convert option
              convert_option = convert_options[key] if convert_options
              convert_option = convert_option ? "#{convert_option} -quality #{retina_quality}" : "-quality #{retina_quality}"
              retina_convert_options["#{key}_retina".to_sym] = convert_option

            end

            ## Append new retina optimzed styles
            value[:styles].merge!(retina_styles)

            ## Set quality convert options
            value[:convert_options] = {} if value[:convert_options].nil?
            value[:convert_options].merge!(retina_convert_options)

            ## Make path work with retina optimization
            original_path = attachment_definitions[key][:path]
            value[:path] = Extensions.optimize_path(original_path) if original_path

            ## Make url work with retina optimization
            original_url = attachment_definitions[key][:url]
            value[:url] = Extensions.optimize_path(original_url) if original_url

          end

        end

      end

    end
  end
end
