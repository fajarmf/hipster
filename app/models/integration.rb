class Integration < ActiveRecord::Base
  belongs_to :user
  has_many :person_mappings
  attr_accessible :harvest_project_id, :pivotal_project_id, :user_id
  attr_accessible :harvest_project_name, :pivotal_project_name
  attr_accessible :project_name, :selection, :client_id

  attr_accessor :project_name, :selection, :client_id

  #validates :harvest_project_id, :uniqueness => { :scope => :pivotal_project_id, message: 'has been mapped' }
  validates_uniqueness_of :harvest_project_id, message: 'has been mapped'
  validates_uniqueness_of :pivotal_project_id, message: 'has been mapped'
  validate :validate_client_not_empty, :on => :create
  validate :validate_project_name_not_empty, :on => :create
  validate :validate_harvest_project_id, :on => :create
  validate :validate_pivotal_project_id, :on => :create

  before_create :prepare_integration

  def harvest_api
    @harvest_api ||= Api::HarvestClient.new(self.user)
  end

  def pivotal_api
    @pivotal_api ||= Api::PivotalClient.new(self.user)
  end

  def prepare_integration
    #For automated project mapping creation
    if self.selection.eql? "auto"
      harvest_project = harvest_api.create_project(self.project_name, self.client_id)
      pivotal_project = pivotal_api.create_project(self.project_name)

      if harvest_project.blank? || harvest_project.id.blank?
        errors.add(:project_name, ' Failed to create new project in Harvest')
      elsif pivotal_project.blank? || pivotal_project.id.blank?
        errors.add(:project_name, ' Failed to create new project in Pivotal Tracker')
      end

      self.harvest_project_id = harvest_project.id
      self.pivotal_project_id = pivotal_project.id
      self.harvest_project_name = project_name
      self.pivotal_project_name = project_name
    #For manual project mapping creation
    else
      self.harvest_project_name = harvest_api.get_harvest_project_name(self.harvest_project_id)
      self.pivotal_project_name = pivotal_api.get_pivotal_project_name(self.pivotal_project_id)
    end
  end

  def create_mapping(pivotal_user, harvest_user)
    pm = person_mappings.build
    pm.pivotal_id = pivotal_user.id
    pm.pivotal_name = pivotal_user.name
    pm.pivotal_email = pivotal_user.email
    pm.harvest_id = harvest_user.id
    pm.harvest_name = "#{harvest_user.try(:first_name)} #{harvest_user.try(:last_name)}"
    pm.harvest_email = harvest_user.email
    pm
  end

  def to_s
    "#{harvest_project_name} - #{pivotal_project_name}"
  end

  def validate_client_not_empty
      errors.add(:client_id, " is required") if (selection.eql? "auto") && client_id.blank?
  end

  def validate_project_name_not_empty
      errors.add(:project_name, " is required") if (selection.eql? "auto") && project_name.blank?
  end

  def validate_harvest_project_id
      errors.add(:harvest_project_id, " is required") if (selection.eql? "manual") && harvest_project_id.blank?
  end

  def validate_pivotal_project_id
      errors.add(:pivotal_project_id, " is required") if (selection.eql? "manual") && pivotal_project_id.blank?
  end
end
