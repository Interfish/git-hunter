require 'json'
require 'rugged'
require 'net/http'
require 'active_record'
require 'erb'
require 'cgi'
require 'uri'

project_root = File.expand_path('..', __dir__).freeze
require_relative project_root + '/config'
require_relative project_root + '/git_hunter/db'

class GitHunterBase
  include GitHunterConfig
  include GitHunterDB

  GIT_HUNTER_ROOT = File.expand_path('..', __dir__).freeze
  GITHUB_API_PREFIX = 'https://api.github.com'.freeze
  GITHUB_HTTPS_PREFIX = 'https://github.com'.freeze
  REPO_DIR = 'repos'.freeze
  REPORT_DIR = 'reports'.freeze
  DB = 'db.sqlite3'.freeze

  class << self

    def root
      GIT_HUNTER_ROOT
    end

    def github_api_prefix
      GITHUB_API_PREFIX
    end

    def github_https_prefix
      GITHUB_HTTPS_PREFIX
    end

    def repo_dir
      REPO_DIR
    end

    def db_name
      DB
    end

    def logger
      GitHunterLogger
    end

    def delete_suffix
      '_deleted_at_' + Time.now.utc.strftime('%y%m%d%H%M%S')
    end
  end

  class GitHunterLogger
    class << self
      def error(message)
        puts '[Error] ' + message.to_s
      end

      def debug(message)
        puts '[Debug] ' + message.to_s
      end

      def info(message)
        puts '[Info]  ' + message.to_s
      end
    end
  end

  class GitHunterError < StandardError
  end
end

Dir[project_root + '/git_hunter/*.rb'].each { |file| require_relative file }
require_relative [project_root, 'git_hunter/models/application_record.rb'].join('/')
Dir[project_root + '/git_hunter/models/*.rb'].each { |file| require_relative file }