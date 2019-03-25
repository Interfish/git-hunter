class Repo < ApplicationRecord
  belongs_to :user
  has_many :blobs, dependent: :destroy

  scope :exist, -> { where('deleted_at IS NULL') }

  def prepare_local_repo(custom_repo_path=nil, custom_repo_git_url=nil)
    @repo_git_url = custom_repo_git_url || repo_git_url
    if !custom_repo_path.nil?
      if Dir.exist? custom_repo_path
        @repo_path = custom_repo_path
      else
        raise GitHunterBase::GitHunterError, 'Git repo path invalid'
      end
    else
      raise GitHunterBase::GitHunterError, 'Git URL Invalid' if !( @repo_git_url =~ URI::regexp)
      if Dir.exist? repo_path
        `cd #{repo_path} && git fetch -n --all`
      else
        `mkdir -p #{user_path} && git clone #{@repo_git_url} #{repo_path}`
      end
      @repo_path = repo_path
    end
  end

  def analyse
    GitHunterBase.logger.info '======================================================================'
    GitHunterBase.logger.info 'User: ' + user.github_user_name
    GitHunterBase.logger.info 'Nickname: ' + (user.nickname || 'nil')
    GitHunterBase.logger.info 'Repo: ' + repo_name
    @repo_rugged = Rugged::Repository.new(@repo_path)

    db_blobs = blobs.exist.pluck(:sha)
    repo_blobs_hash = blobs_in_repo

    handle_deleted_blobs(db_blobs, repo_blobs_hash)
    sync_new_blobs(repo_blobs_hash)

    targets = blobs.exist.where(need_scan: true)
    targets.each {|blob| blob.analyse(@repo_rugged)}
    targets.update_all(need_scan: false)
  rescue Rugged::OSError => e
    GitHunterBase.logger.error "Rugged fail to initialize #{repo_path}. Clone may failed."
  end

  def handle_deleted_blobs(db_blobs, repo_blobs_hash)
    deleted_blobs = db_blobs.reject {|sha| repo_blobs_hash.key? sha}
    if deleted_blobs.size > 0
      deleted_blobs_collection = blobs.exist.where(sha: deleted_blobs)
      deleted_blobs_collection.each do |b|
        b.update!(
          deleted_at: Time.now.utc,
          need_scan: false
        )
        b&.findings&.update_all(is_valid: false)
      end
    end
  end

  def sync_new_blobs(repo_blobs_hash)
    repo_blobs_hash.each do |sha, info|
      blobs.exist.where(sha: sha).first_or_create!(
        earliest_commit_sha: info[0],
        file_path: info[1],
        need_scan: true
      )
    end
  end

  def repo_path
    [GitHunterBase.root, GitHunterBase.repo_dir, user.github_user_name, repo_name].join('/')
  end

  def temp_repo?
    repo_name.start_with?('temp_repo@')
  end

  def repo_link
    if temp_repo?
      'Temp Repo, No Link'
    else
      [GitHunterBase::GITHUB_HTTPS_PREFIX, user.github_user_name, repo_name].join('/')
    end
  end

  private

  def blobs_in_repo
    blobs_hash = {}
    new_worker.walk do |commit_obj|
      commit_obj.tree.walk_blobs do |root, blob_hash|
        blobs_hash[blob_hash[:oid]] = [commit_obj.oid, root + blob_hash[:name]] unless blobs_hash.key?(blob_hash[:oid])
      end
    end
    blobs_hash
  end

  def new_worker
    walker = Rugged::Walker.new(@repo_rugged)
    walker.sorting(Rugged::SORT_DATE | Rugged::SORT_REVERSE)
    @repo_rugged.branches.each do |b|
      next unless b.name.include? 'origin'
      next if b.name.include? 'HEAD'
      walker.push(b.target)
    end
    walker
  end

  def user_path
    [GitHunterBase.root, GitHunterBase.repo_dir, user.github_user_name].join('/')
  end

  def repo_git_url
    [GitHunterBase.github_https_prefix, user.github_user_name, repo_name].join('/') + '.git'
  end
end