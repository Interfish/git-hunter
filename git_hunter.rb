#!/usr/bin/ruby
require_relative 'git_hunter/git_hunter_base'

HELP = <<~HELP

Usage:
    Action explanation:
      run    - execute analysing process
      report - generate HTML report for analysing result
      mark   - mark some target's findings in DB as false positive, thus will not show in your next generated report
      lookup - lookup github_username by nickname, or vice versa.

      run                                                                         - Analyse users in user_list.txt
      run user (<github_user_link> | <github_username>) [nickname]                - Analyse <github_username>'s all repositories, nickname is optional
      run repo (<github_repo_link> | (<github_username> <repo_name>)) [nickname]  - Analyse <github username>'s repo '<repo_name>', nickname is optional
      run global                                                                  - Global Seach for sensitive words in config

      report                                                                      - Generate html report for all users in DB
      report user <github_username>                                               - Generate html report for <github_username> in DB
      report repo <github_username> <repo_name>                                   - Generate html report for <github_username>'s <repo_name> in DB
      report global                                                               - Generate global report in DB

      mark all                                                                    - Mark all users' findings in DB as false positive
      mark user <github_username>                                                 - Mark <github_username>'s findings in DB as false positive
      mark repo <github_username> <repo_name>                                     - Mark <github_username> <repo_name>'s findings in DB as false positive
      mark global                                                                 - Mark all global findings as false positive
      mark global <github_username>                                               - Mark <github_username>'s global findings as false positive

      lookup user <nickname>                                                      - Lookup github_username by nickname
      lookup nickname <github_username>                                           - Lookup nickname by github_username

Examples:
      run user abc batman                                                         - Analyse github user abc's all repos, and give a nickname 'batman' to this user
      run user https://github.com/abc batman                                      - Same as above
      run repo abc def                                                            - Analyse abc's repo def
      run repo https://github.com/abc/def                                         - Same as above
      report user abc                                                             - Report findings of abc
      report repo abc def                                                         - Report findings in abc's repo def
      mark user abc                                                               - Mark findings of user abc as false positive
      lookup nickname batman                                                      - Lookup batman's github_user_name
HELP

def run_all
  File.open('user_list.txt').read.each_line do |line|
    args = line.split
    GitHunterCore.new(extract_user_and_repo(args[0]), nil, args[1]).run
  end
end

def extract_user_and_repo(link)
  return link unless link?(link)
  path = URI.parse(link).path.split('/').reject(&:nil?)
  return path.first if path.size == 1
  return path.first, path.second
end

def link?(str)
  str.start_with?('http')
end

if ARGV[0] == 'run'
  if ARGV[1].nil?
    run_all
    GitHunterRenderer.new.run
  elsif ARGV[1] == 'user'
    GitHunterCore.new(extract_user_and_repo(ARGV[2]), nil, ARGV[3]).run
    GitHunterRenderer.new(ARGV[2]).run
  elsif ARGV[1] == 'repo'
    if link?(ARGV[2])
      user, repo = extract_user_and_repo(ARGV[2])
      nickname = ARGV[3]
    else
      user = ARGV[2]
      repo = ARGV[3]
      nickname = ARGV[4]
    end
    GitHunterCore.new(user, repo, ARGV[4]).run
    GitHunterRenderer.new(user, repo).run
  elsif ARGV[1] == 'global'
    GitHunterCore.new.run_global
    GitHunterRenderer.new.run_global``
  else
    puts HELP
  end
elsif ARGV[0] == 'report'
  if ARGV[1].nil?
    GitHunterRenderer.new.run
  elsif ARGV[1] == 'user'
    GitHunterRenderer.new(ARGV[2]).run
  elsif ARGV[1] == 'repo'
    GitHunterRenderer.new(ARGV[2], ARGV[3]).run
  elsif ARGV[1] == 'global'
    GitHunterRenderer.new.run_global
  else
    puts HELP
  end
elsif ARGV[0] == 'mark'
  if ARGV[1] == 'all'
    GitHunterCore.new.mark
  elsif ARGV[1] == 'user'
    GitHunterCore.new.mark(ARGV[2])
  elsif ARGV[1] == 'repo'
    GitHunterCore.new.mark(ARGV[2], ARGV[3])
  elsif ARGV[1] == 'global'
    if ARGV[2].nil?
      GitHunterCore.new.mark_global
    else
      GitHunterCore.new.mark_global(ARGV[2])
    end
  else
    puts HELP
  end
elsif ARGV[0] == 'lookup'
  if ARGV[1] == 'user'
    puts GitHunterCore.new.lookup(:user, ARGV[2]) || 'nil'
  elsif ARGV[1] == 'nickname'
    puts GitHunterCore.new.lookup(:nickname, ARGV[2]) || 'nil'
  else
    puts HELP
  end
else
  puts HELP
end