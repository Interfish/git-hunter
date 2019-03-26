class Blob < ApplicationRecord
  belongs_to :repo
  has_many :findings, dependent: :destroy

  scope :exist, -> { where('deleted_at IS NULL') }

  def analyse(repo_rugged)
    blob_obj = repo_rugged.lookup(sha)
    commit_obj = repo_rugged.lookup(earliest_commit_sha)
    analyser = GitHunterAnalyser.new(id, blob_obj, commit_obj, file_path)
    analyser.run
  rescue ArgumentError => e # prevent utf-8 code error
    GitHunterBase.logger.debug e.message
  end

  def file_link
    if repo.temp_repo?
      'javascript:void(0)'
    else
      "window.open('#{[GitHunterBase::GITHUB_HTTPS_PREFIX, repo.user.github_user_name, repo.repo_name, 'blob', blob.earliest_commit_sha, blob.file_path].join('/')}')"
    end
  end

  def commit_link
    if repo.temp_repo?
      'javascript:void(0)'
    else
      "window.open('#{[GitHunterBase::GITHUB_HTTPS_PREFIX, repo.user.github_user_name, repo.repo_name, 'commit', blob.earliest_commit_sha].join('/')}')"
    end
  end
end