# == Schema Information
# Schema version: 20090824160651
#
# Table name: position_series
#
#  id           :integer(4)      not null, primary key
#  position_id  :integer(4)
#  indicator_id :integer(4)
#  date         :date
#  value        :float
#

class PositionSeries < ActiveRecord::Base
end