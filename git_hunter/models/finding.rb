class Finding < ApplicationRecord
  belongs_to :blob
  serialize :marks
end