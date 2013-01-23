require 'yaml'
require 'github_api'

module JiraJson
  def self.config(key)
    @config ||= YAML.load_file(File.dirname(__FILE__)+"/../config/config.yml")
    @config[key]
  end

  def self.github
    Github.new :user => config('github_issues_user'),
      :repo => config('github_issues_repo'),
      :oauth_token => config('github_oauth_token')
  end

  def self.username(gh_user)
    @usermap ||= YAML.load_file(File.dirname(__FILE__)+"/../config/usermap.yml")
    @usermap[gh_user] || gh_user
  end
end
