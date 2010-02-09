# == Schema Information
# Schema version: 20100205165537
#
# Table name: derived_values
#
#  id                    :integer(4)      not null, primary key
#  ticker_id             :integer(4)
#  derived_value_type_id :integer(4)
#  date                  :date
#  time                  :datetime
#  value                 :float
#

# Copyright © Kevin P. Nolan 2009 All Rights Reserved.

class DerivedValue < ActiveRecord::Base
  belongs_to :derived_value_type
end
