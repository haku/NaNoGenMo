require 'fileutils'

module NaNoGenMo

  class Utils

    BASE_NAME = '.nanogenmo'

    def self.config_dir
      dir = "#{File.expand_path('~')}/#{BASE_NAME}"
      FileUtils.mkdir_p dir if !Dir.exists?(dir)
      dir
    end

  end

end
