class GitHunterCore < GitHunterBase
  def initialize(user=nil, repo=nil, nickname=nil)
    prepare_db
    @user_name = user
    @nickname = nickname
    @repo_name = repo
    # Log sql
    # ActiveRecord::Base.logger = Logger.new(STDOUT)
  rescue GitHunterBase::GitHunterError => e
    GitHunterBase.logger.error e.message
  end

  def run
    check_params
    @repos_json = User.fetch_repo_info(@user_name)
    @user = User.where(github_user_name: @user_name).first_or_create!
    @user.update!(nickname: @nickname) if @nickname.present?
    if @repo_name
      check_single_repo
    else
      check_all_repo
    end
    label_deleted_repo
  rescue GitHunterBase::GitHunterError => e
    GitHunterBase.logger.error e.message
  end

  def run_custom_link(link)
    create_user_and_repo_for_custom_path_or_link
    @repo.prepare_local_repo(nil, link)
    @repo.analyse
    return @user_name, @repo_name
  end

  def run_local(path)
    create_user_and_repo_for_custom_path_or_link
    @repo.prepare_local_repo(path, nil)
    @repo.analyse
    return @user_name, @repo_name
  end

  def create_user_and_repo_for_custom_path_or_link
    @user_name = Time.now.utc.strftime('temp_user@%Y%m%d%H%M%S')
    @repo_name = Time.now.utc.strftime('temp_repo@%Y%m%d%H%M%S')
    @user = User.where(github_user_name: @user_name).first_or_create!
    @user.update!(nickname: @nickname) if @nickname.present?
    Time.now.utc.strftime('temp_user@%Y%m%d%H%M%S')
    @repo = Repo.exist.where(user: @user, repo_name: @repo_name).first_or_create!
  end

  def check_single_repo
    unless verify_repo_is_in_list
      err_msg = @repo_name + ' is not in remote list of ' + @user.github_user_name
      raise GitHunterBase::GitHunterError, err_msg
    end
    @repo = Repo.exist.where(user: @user, repo_name: @repo_name).first_or_create!
    @repo.prepare_local_repo
    @repo.analyse
  end

  def check_all_repo
    @repos_json.each do |repo_json|
      next if repo_json['fork']
      next if (SKIPPABLE_REPO.each {|name| break true if repo_json['name'].match?(Regexp.new(name))} == true)
      repo = Repo.exist.where(user: @user, repo_name: repo_json['name']).first_or_create!
      GC.enable
      GC.start(full_mark: true, immediate_sweep: true)
      repo.prepare_local_repo
      repo.analyse
    end
  end

  def prepare_db
    db_path = [GIT_HUNTER_ROOT, DB].join('/')
    unless File.exist? db_path
      create_db
      connect_db
      migrate_db
    else
      connect_db
    end
  end

  def verify_repo_is_in_list
    @repos_json.map {|repo| repo['name']}.include? @repo_name
  end


  def analyse_repo(repo)
    GitHunterBase.logger.info 'Analysing ' + @nickname + ', ' + @user + ' ===> ' + repo

  end

  def label_deleted_repo
    deleted_repos = Repo.exist.where(user: @user).where.not(repo_name: @repos_json.map {|repo_json| repo_json['name']})
    if deleted_repos.size > 0
      GitHunterBase.logger.info @user.github_user_name + ' deleted repo ===> ' + deleted_repos.pluck(:repo_name).to_s
      deleted_repos.each do |repo|
        `mv #{repo.repo_path} #{repo.repo_path + GitHunterBase.delete_suffix}`
        repo.update!(
          deleted_at: Time.now.utc
        )
        repo&.blobs&.exist&.each do |blob|
          blob.update!(
            need_scan: false,
            deleted_at: Time.now.utc
          )
          blob&.findings&.update_all(is_valid: false)
        end
      end
    end
  end

  def run_global
    prepare_sensitive_word
    search_each_word
  rescue GitHunterBase::GitHunterError => e
    GitHunterBase.logger.info e.message
  end

  def prepare_sensitive_word
    GLOBAL_SENSITIVE_WORDS.each do |word|
      unless GlobalFindingWord.find_by(sensitive_word: word)
        GlobalFindingWord.create(
          sensitive_word: word,
          count: 0,
          updated_at: Time.now.utc
        )
      end
    end
  end

  def search_each_word
    GLOBAL_SENSITIVE_WORDS.each do |word|
      res = GlobalFinding.search_code(word)
      global_finding_word = GlobalFindingWord.find_by(sensitive_word: word)
      delete_global_record_if_necessary(global_finding_word)
      new_findings_num = [res['total_count'] - global_finding_word.count, GLOBAL_ADDITION_MAX_SIZE].min
      GitHunterBase.logger.debug "total #{res['total_count']} findings of word '#{word}' on github."
      GitHunterBase.logger.debug "currently #{global_finding_word.count} findings of word '#{word}' in database."
      res['items'].each_with_index do |item, i|
        begin
          break if i > new_findings_num - 1
          next if words_unbreakable?(item['text_matches'][0]['fragment'], word)
          GlobalFinding.create!(
            global_finding_word: global_finding_word,
            github_user_name: item['repository']['owner']['login'],
            repo_name: item['repository']['name'],
            path: item['path'],
            blob_sha: item['sha'],
            url: item['html_url'],
            content: item['text_matches'][0]['fragment'],
            marks: item['text_matches'][0]['matches'].map {|a| a['indices']},
            is_valid: true,
            created_at: Time.now.utc
          )
        rescue ActiveRecord::RecordNotUnique => e
          GitHunterBase.logger.debug 'Duplicated blob, skipping ...'
        end
      end
      global_finding_word.update!(
        count: res['total_count'],
        updated_at: Time.now.utc
      )
      sleep(30) # github search have its own rate limit other than api rate limit.
    end
  end

  def delete_global_record_if_necessary(global_finding_word)
    if global_finding_word.global_findings.count > GlOBAL_FINDING_MAX_SIZE
      global_finding_word.global_findings.destroy_all
    end
  end

  def words_unbreakable?(fragment, search_word)
    fragment =~ /[^a-zA-Z0-9]#{search_word}[^a-zA-Z0-9]/i ? false : true
  end

  def mark(user=nil, repo=nil)
    prepare_db
    findings = Finding.joins(blob: [repo: [:user]]).where('findings.is_valid = ?', true)
    if user
      findings = findings.where('users.github_user_name = ?', user)
      if repo
        findings = findings.where('repos.repo_name = ?', repo)
      end
    end
    findings.update_all(is_valid: false)
  end

  def mark_global(user=nil)
    prepare_db
    global_findings = GlobalFinding.where(is_valid: true)
    if user
      global_findings = global_findings.where(github_user_name: user)
    end
    global_findings.update_all(is_valid: false)
  end

  def lookup(type, name)
    if type == :user
      User.find_by(github_user_name: name)&.nickname
    elsif type == :nickname
      User.find_by(nickname: name)&.github_user_name
    end
  end

  private

  def check_params
    if @user_name.nil?
      raise GitHunterBase::GitHunterError, 'Username missing'
    end
  end
end