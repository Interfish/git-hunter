class User < ApplicationRecord
  has_many :repos, dependent: :destroy

  PER_PAGE = 50.freeze

  def self.fetch_repo_info(github_user_name)
    result = []
    page = 1
    while (repos = fetch_one_round(github_user_name, page)).count > 0
      result += repos
      page += 1
    end
    result
  end

  private

  def self.fetch_one_round(github_user_name, page)
    url = [GitHunterBase.github_api_prefix, 'users', github_user_name, 'repos'].join('/') + '?access_token=' + GitHunterBase::GITHUB_OAUTH_TOKEN + "&per_page=#{PER_PAGE}&page=#{page}"
    res = Net::HTTP.get_response(URI(url))
    if res.code == '403'
      raise GitHunterBase::GitHunterError, 'Probably reached Github API request rate limit.'
    elsif res.code == '404'
      raise GitHunterBase::GitHunterError, "Github user #{github_user_name} 404 Not Found"
    end
    sleep 2
    JSON.parse(res.body)
  end
end