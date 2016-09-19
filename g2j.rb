require 'yaml'
require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'octokit'
require 'date'

# ===== Config here =====
config = YAML.load_file('config.yml')
jirakey = config['jirakey']
org = config['org']
reponame = config['reponame']
token = config['token']
import_state = config['state']
# =======================

logger = Logger.new(STDOUT)

def jira_date(d)
  DateTime.parse(d.to_s).strftime('%Y-%m-%dT%H:%m:%S+00:00')
end

def reformat(s)
  s.gsub('```', '{code}')
   .gsub('👍', '(y)')
   .gsub(/[\u{203C}\u{2049}\u{20E3}\u{2122}\u{2139}\u{2194}-\u{2199}\u{21A9}-\u{21AA}\u{231A}-\u{231B}\u{23E9}-\u{23EC}\u{23F0}\u{23F3}\u{24C2}\u{25AA}-\u{25AB}\u{25B6}\u{25C0}\u{25FB}-\u{25FE}\u{2600}-\u{2601}\u{260E}\u{2611}\u{2614}-\u{2615}\u{261D}\u{263A}\u{2648}-\u{2653}\u{2660}\u{2663}\u{2665}-\u{2666}\u{2668}\u{267B}\u{267F}\u{2693}\u{26A0}-\u{26A1}\u{26AA}-\u{26AB}\u{26BD}-\u{26BE}\u{26C4}-\u{26C5}\u{26CE}\u{26D4}\u{26EA}\u{26F2}-\u{26F3}\u{26F5}\u{26FA}\u{26FD}\u{2702}\u{2705}\u{2708}-\u{270C}\u{270F}\u{2712}\u{2714}\u{2716}\u{2728}\u{2733}-\u{2734}\u{2744}\u{2747}\u{274C}\u{274E}\u{2753}-\u{2755}\u{2757}\u{2764}\u{2795}-\u{2797}\u{27A1}\u{27B0}\u{2934}-\u{2935}\u{2B05}-\u{2B07}\u{2B1B}-\u{2B1C}\u{2B50}\u{2B55}\u{3030}\u{303D}\u{3297}\u{3299}\u{1F004}\u{1F0CF}\u{1F170}-\u{1F171}\u{1F17E}-\u{1F17F}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F1E7}-\u{1F1EC}\u{1F1EE}-\u{1F1F0}\u{1F1F3}\u{1F1F5}\u{1F1F7}-\u{1F1FA}\u{1F201}-\u{1F202}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}-\u{1F251}\u{1F300}-\u{1F320}\u{1F330}-\u{1F335}\u{1F337}-\u{1F37C}\u{1F380}-\u{1F393}\u{1F3A0}-\u{1F3C4}\u{1F3C6}-\u{1F3CA}\u{1F3E0}-\u{1F3F0}\u{1F400}-\u{1F43E}\u{1F440}\u{1F442}-\u{1F4F7}\u{1F4F9}-\u{1F4FC}\u{1F500}-\u{1F507}\u{1F509}-\u{1F53D}\u{1F550}-\u{1F567}\u{1F5FB}-\u{1F640}\u{1F645}-\u{1F64F}\u{1F680}-\u{1F68A}]/, '')
end

fullname = "#{org}/#{reponame}"
client = Octokit::Client.new(access_token: token)
client.auto_paginate = true
repo = client.repo fullname

logger.info "Enumerating #{import_state} issues for #{fullname}"
issues = client.list_issues fullname, state: import_state
output = []

issues.each do |issue|
  logger.debug "Fetching #{issue.state} issue ##{issue.number} #{issue.title}"
  issue_jira = {
    "key" => "#{jirakey}-#{issue.number}",
    "status" => issue.state.capitalize,
    "resolution" => (issue.state == 'closed') ? 'Fixed' : nil,
    "reporter" => issue.user.login,
    "created" => jira_date(issue.created_at),
    "updated" => jira_date(issue.updated_at),
    "summary" => issue.title,
    "issueType" => "Task",
    "description" => reformat(issue.body),
    "labels" => issue.labels.collect { |l| l.name },
    "comments" => []
  }
  unless issue.assignee.nil?
    issue_jira["assignee"] = issue.assignee.login
  end
  issue_comments = client.issue_comments(fullname, issue.number, state: 'all')
  logger.debug "Fetched #{issue_comments.size} comments for ##{issue.number}"
  issue_comments.each do |comment|
    issue_jira['comments'] << {
      "body" => reformat(comment.body),
      "author" => comment.user.login,
      "created" => jira_date(comment.created_at)
    }
  end

  # Pull request? Make a comment for it
  pr = issue.pull_request
  if pr
    pr_info = client.pull_request fullname, issue.number
    issue_jira['comments'] << {
      "body" => "Branch: #{pr_info.head.label}",
      "author" => pr_info.user.login,
      "created" => jira_date(pr_info.created_at)
    }
  end

  issue_events = client.issue_events(fullname, issue.number)
  logger.debug "Fetched #{issue_events.size} events for ##{issue.number}"
  issue_events.each do |event|
    next unless %w(
      merged
      referenced
      closed
      reopened
      head_ref_deleted
      head_ref_restored
    ).include? event.event
    text = case event.event
    when 'head_ref_deleted'
      "Removed branch"
    when 'head_ref_restored'
      "Restored branch"
    else
      event.event.capitalize
    end
    commit = event.commit_id
    info = if commit
      " ([#{commit[0,6]}|https://github.com/#{fullname}/commit/#{commit}])"
    else
      nil
    end
    issue_jira['comments'] << {
      "body" => "#{text}#{info}",
      "author" => event.actor.login,
      "created" => jira_date(event.created_at)
    }
  end

  output << issue_jira
end

filename = "#{reponame}.json"

logger.info "Writing #{filename}"
project_jira = { 'projects' => [{
  'name' => reponame,
  'key' => jirakey,
  'externalName' => reponame,
  'issues' => output
}]}

File.open(filename,"w") do |f|
  f.write(JSON.pretty_generate(project_jira))
end

