class GitHunterRenderer < GitHunterBase
  def initialize(user_name=nil, repo_name=nil)
    check_params
    prepare_reports_dir
    @user_name = user_name
    @repo_name = repo_name
    db_path = [GitHunterBase.root, GitHunterBase.db_name].join('/')
    @template_html = File.open([GIT_HUNTER_ROOT, 'git_hunter', 'templates', 'report.html.erb'].join('/')).read
    @template_js = File.open([GIT_HUNTER_ROOT, 'git_hunter', 'templates', 'report.js'].join('/')).read
    @template_css = File.open([GIT_HUNTER_ROOT, 'git_hunter', 'templates', 'report.css'].join('/')).read
    connect_db
    # Log sql
    # ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  def run
    get_result
    report = ERB.new(@template_html)
    result = report.result(get_binding)
    # file_name = 'test.html'
    file_name = Time.now.strftime('%y%m%d%H%M%S') +
                (@user_name.nil? ? '' : ('_' + @user_name.to_s)) +
                (@repo_name.nil? ? '' : ('_' + @repo_name.to_s)) +
                '.html'
    f = File.new([GIT_HUNTER_ROOT, REPORT_DIR, file_name].join('/'), 'w+')
    f.write result
    f.close
    try_open(file_name)
  end

  def get_result
    #vul_repos = Repo.includes(:user).joins(blobs: [:findings]).where('findings.is_valid = ?', true).order('users.id ASC, repos.id ASC')
    vul_repos = Repo.includes(:user, blobs: [:findings]).where('findings.is_valid = ?', true).references(:findings).order('users.id ASC, repos.id ASC')
    users = User.all
    repos = Repo.exist.all
    blobs = Blob.exist.all
    findings = Finding.where(is_valid: true)
    if !@user_name.nil?
      user = User.find_by(github_user_name: @user_name)
      users = users.where(github_user_name: @user_name)
      repos = repos.where(user: users)
      blobs = blobs.where(repo: repos)
      findings = findings.where(blob: blobs)
      if !@repo_name.nil?
        @result = vul_repos.where(user: user, repo_name: @repo_name).to_a
        repos = repos.where(repo_name: @repo_name)
        blobs = blobs.where(repo: repos)
        findings = findings.where(blob: blobs)
      else
        @result = vul_repos.where(user: user).to_a
      end
    else
      @result = vul_repos.to_a
    end
    # record stats and decorated
    @user_count = users.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @repo_count = repos.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @blob_count = blobs.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    @finding_count = findings.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def run_global
    @template_html = File.open([GIT_HUNTER_ROOT, 'git_hunter', 'templates', 'global_report.html.erb'].join('/')).read
    @template_css = File.open([GIT_HUNTER_ROOT, 'git_hunter', 'templates', 'global_report.css'].join('/')).read
    get_global_result
    report = ERB.new(@template_html)
    result = report.result(get_binding)
    file_name = Time.now.strftime('%y%m%d%H%M%S') + '_global.html'
    # file_name = 'test_global.html'
    f = File.new([GIT_HUNTER_ROOT, REPORT_DIR, file_name].join('/'), 'w+')
    f.write result
    f.close
    try_open(file_name)
  end

  def get_global_result
    @words = GlobalFindingWord.includes(:global_findings).where('global_findings.is_valid = ?', true).references(:global_findings)
    @global_findings = GlobalFinding.where(is_valid: true)
  end

  private

  def check_params
    unless @repo_name.nil?
      raise(GitHunterBase::GitHunerError, "Render\'s args is not right!") if @user_name.nil?
    end
  end

  def formatting_numbers
    [@user_count, @repo_count, @blob_count, @finding_count].each do |c|
      c = c.to_s.reverse.gsub(/(\d{3})/,"\\1,").chomp(",").reverse
    end
    puts [@user_count, @repo_count, @blob_count, @finding_count].first.class
  end

  def get_binding
    binding
  end

  def prepare_reports_dir
    unless Dir.exist? [GIT_HUNTER_ROOT, REPORT_DIR].join('/')
      Dir.mkdir([GIT_HUNTER_ROOT, REPORT_DIR].join('/'), 0775)
    end
  end

  def get_snippet(content, marks)
    return content if marks.nil?
    result = get_marked_snippet(content, marks)
    result = CGI.escapeHTML(result)
    format_snippet(result)
  end

  def get_marked_snippet(content, marks)
    inserted = 0
    marks.each do |mark|
      content = content.insert(mark.first + inserted * 13, '=mARk~')
      content = content.insert(mark.second + 6 + inserted * 13, '=!mARk~')
      inserted += 1
    end
    content
  end

  def format_snippet(content)
    content = content.gsub(/\n|\r|\r\n/, '<br>')
    content = content.gsub(/=mARk~/, '<mark>')
    content = content.gsub(/=!mARk~/, '</mark>')
  end

  def try_open(file_name)
    # Windows
    if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
      `start "" "file://#{[GIT_HUNTER_ROOT, REPORT_DIR, file_name].join('/')}"`
    # Mac OS
    elsif (/darwin/ =~ RUBY_PLATFORM) != nil
      `open #{[GIT_HUNTER_ROOT, REPORT_DIR, file_name].join('/')}`
    # Linux, probably
    else
      `xdg-open #{[GIT_HUNTER_ROOT, REPORT_DIR, file_name].join('/')}`
    end
  rescue StandardError
  end
end