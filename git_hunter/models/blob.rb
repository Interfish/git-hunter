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
end