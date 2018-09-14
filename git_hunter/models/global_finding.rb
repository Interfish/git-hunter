class GlobalFinding < ApplicationRecord
  belongs_to :global_finding_word
  serialize :marks

  def self.search_code(word)
    url = [GitHunterBase::GITHUB_API_PREFIX, 'search', 'code'].join('/') +
          "?q=#{word}&sort=indexed&order=desc&per_page=#{GitHunterBase::GLOBAL_ADDITION_MAX_SIZE.to_s}&page=1"
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "token #{GitHunterBase::GITHUB_OAUTH_TOKEN}"
    req['Accept'] = 'application/vnd.github.v3.text-match+json'
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = (uri.scheme == "https")
    res = http.request(req)
    res = JSON.parse(res.body)
    raise GitHunterBase::GitHunterError, 'reached search rate limit! Try again later' if res['message']
    res
  rescue GitHunterBase::GitHunterError => e
    GitHunterBase.logger.info e.message
    GitHunterBase.logger.info 'sleeping 30s ...'
    sleep(30)
    retry
  end
end