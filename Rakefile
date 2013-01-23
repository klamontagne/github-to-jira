require 'rubygems'
require 'bundler/setup'
require 'rake'
require 'logger'
require 'json/pure'
require File.join(File.dirname(__FILE__), 'lib/jirajson.rb')

logger = Logger.new(STDOUT)

desc "Generate issues json"
task :generate_json do
  logger.info "Enumerating all issues for %s" % JiraJson.config('github_issues_repo')
  issues = []

  ['open','closed'].each do |state|
    result = JiraJson.github.issues.list:user => JiraJson.config('github_issues_user'),
      :repo => JiraJson.config('github_issues_repo'),
      :sort => 'created',
      :direction => 'desc',
      :state => state

    result.each_page do |page|
      page.each do |issue|
        logger.debug "Fetching #{state} issue ##{issue.number} #{issue.title}"
        issue_jira = {
          "status" => state.capitalize,
          "reporter" => JiraJson.username(issue.user.login),
          "created" => issue.created_at,
          "updated" => issue.updated_at,
          "summary" => issue.title,
          "externalId" => issue.number,
          "issueType" => "Bug",
          "description" => issue.body,
          "labels" => issue.labels.collect { |l| l.name },
          "comments" => []
        }
        unless issue.assignee.nil?
          issue_jira["assignee"] = JiraJson.username(issue.assignee.login)
        end
        if issue.comments > 0
          logger.debug "Fetching #{issue.comments} comments for ##{issue.number}"
          comments = JiraJson.github.issues.comments.all JiraJson.config('github_issues_user'),
            JiraJson.config('github_issues_repo'),
            :issue_id =>  issue.number
          comments.each do |comment|
            issue_jira['comments'] << {
              "body" => comment.body,
              "author" => JiraJson.username(comment.user.login),
              "created" => comment.created_at
            }
          end
        end
        issues << issue_jira
      end
    end
  end

  filename = JiraJson.config('github_issues_repo') + '.json'

  logger.info "Writing #{filename}"
  project_jira = { 'projects' => [{
    'name' => JiraJson.config('jira_project'),
    'key' => JiraJson.config('jira_project_key'),
    'externalName' => JiraJson.config('github_issues_repo'),
    'issues' => issues
  }]}

  File.open(filename,"w") do |f|
    f.write(JSON.pretty_generate(project_jira))
  end
end
