class ClassTiming < ActiveRecord::Base
  has_many :timetable_entries , :dependent => :destroy
  belongs_to :batch

  validates_presence_of :name
  validates_uniqueness_of :name,  :scope => :batch_id

  named_scope :for_batch, lambda { |b| { :conditions => { :batch_id => b.to_i },  :order =>'start_time ASC' } }
  named_scope :default, :conditions => { :batch_id => nil, :is_break => false }, :order =>'start_time ASC'

  def validate
    errors.add(:end_time, "#{t('should_be_later')}.") \
      if self.start_time > self.end_time \
      unless self.start_time.nil? or self.end_time.nil?
    self_check= self.new_record? ? "" : "id != #{self.id} and "
    start_overlap = !ClassTiming.find(:first, :conditions=>[self_check+"start_time < ? and end_time > ? and batch_id #{self.batch_id.nil? ? 'is null' : '='+ self.batch_id.to_s}", self.start_time,self.start_time]).nil?
    end_overlap = !ClassTiming.find(:first, :conditions=>[self_check+"start_time < ? and end_time > ? and batch_id #{self.batch_id.nil? ? 'is null' : '='+ self.batch_id.to_s}", self.end_time,self.end_time]).nil?
    between_overlap = !ClassTiming.find(:first, :conditions=>[self_check+"start_time < ? and end_time > ? and batch_id #{self.batch_id.nil? ? 'is null' : '='+ self.batch_id.to_s}",self.end_time, self.start_time]).nil?
    errors.add(:start_time, "#{t('overlap_existing_class_timing')}.") if start_overlap
    errors.add(:end_time, "#{t('overlap_existing_class_timing')}.") if end_overlap
    errors.add_to_base("#{t('class_time_overlaps_with_existing')}.") if between_overlap
    errors.add(:start_time,"#{t('is_same_as_end_time')}") if self.start_time == self.end_time
  end
end
