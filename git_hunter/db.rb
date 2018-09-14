require 'sqlite3'

module GitHunterDB
  def create_db
    SQLite3::Database.new [GitHunterBase::GIT_HUNTER_ROOT, GitHunterBase::DB].join('/')
  end

  def migrate_db
    CreateUser.new.change
    CreateRepo.new.change
    CreateBlob.new.change
    CreateFinding.new.change
    CreateGlobalFindingWord.new.change
    CreateGlobalFinding.new.change
  end

  def connect_db
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: [GitHunterBase::GIT_HUNTER_ROOT, GitHunterBase::DB].join('/'),
      pool: 5,
      timeout: 5000
    )
  end
end

# Migrations
class CreateUser < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.string :github_user_name
      t.string :nickname
    end
  end
end

class CreateRepo < ActiveRecord::Migration[5.1]
  def change
    create_table :repos do |t|
      t.references :user, foreign_key: true
      t.string :repo_name
      t.datetime :deleted_at, default: nil
    end
  end
end

class CreateBlob < ActiveRecord::Migration[5.1]
  def change
    create_table :blobs do |t|
      t.references :repo, foreign_key: true
      t.string :earliest_commit_sha
      t.string :sha
      t.string :file_path
      t.boolean :need_scan
      t.datetime :deleted_at, default: nil
    end

    add_index :blobs, [:sha, :need_scan]
  end
end

class CreateFinding < ActiveRecord::Migration[5.1]
  def change
    create_table :findings do |t|
      t.references :blob, foreign_key: true
      t.string :line_no
      t.string :content
      t.string :marks
      t.string :description
      t.boolean :is_valid
      t.datetime :created_at
    end
  end
end

class CreateGlobalFindingWord < ActiveRecord::Migration[5.1]
  def change
    create_table :global_finding_words do |t|
      t.string :sensitive_word
      t.integer :count
      t.datetime :updated_at
    end
  end
end

class CreateGlobalFinding < ActiveRecord::Migration[5.1]
  def change
    create_table :global_findings do |t|
      t.references :global_finding_word, foreign_key: true
      t.string :github_user_name
      t.string :repo_name
      t.string :path
      t.string :blob_sha
      t.string :url
      t.string :content
      t.string :marks
      t.boolean :is_valid
      t.datetime :created_at
    end
    add_index :global_findings, [:github_user_name, :repo_name, :blob_sha], :unique => true, :name => 'unique_blob_index'
  end
end

