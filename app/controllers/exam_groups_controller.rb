class ExamGroupsController < ApplicationController
  before_filter :login_required
  before_filter :initial_queries
  before_filter :protect_other_student_data
  before_filter :restrict_employees_from_exam
  before_filter :protect_other_batch_exams, :only => [:show, :index]
  in_place_edit_for :exam_group, :name
  filter_access_to :all
  in_place_edit_for :exam, :maximum_marks
  in_place_edit_for :exam, :minimum_marks
  in_place_edit_for :exam, :weightage

  def index
    @exam_groups = @batch.exam_groups
    if @current_user.employee?
      @user_privileges = @current_user.privileges
      @employee_subjects= @current_user.employee_record.subjects.map { |n| n.id}
      if @employee_subjects.empty? and !@user_privileges.map{|p| p.name}.include?('ExaminationControl') and !@user_privileges.map{|p| p.name}.include?('EnterResults')
        flash[:notice] = "#{t('flash_msg4')}"
        redirect_to :controller => 'user', :action => 'dashboard'
      end
    end
  end

  def new
    @user_privileges = @current_user.privileges
    if !@current_user.admin? and !@user_privileges.map{|p| p.name}.include?('ExaminationControl') and !@user_privileges.map{|p| p.name}.include?('EnterResults')
      flash[:notice] = "#{t('flash_msg4')}"
      redirect_to :controller => 'user', :action => 'dashboard'
    end
  end

  def create
    @exam_group = ExamGroup.new(params[:exam_group])
    @exam_group.batch_id = @batch.id
    @type = @exam_group.exam_type
    if @exam_group.save
      flash[:notice] =  "#{t('flash1')}"
      redirect_to batch_exam_groups_path(@batch)
    else
      render 'new'
    end
  end

  def edit
    @exam_group = ExamGroup.find params[:id]
  end

  def update
    @exam_group = ExamGroup.find params[:id]
    if @exam_group.update_attributes(params[:exam_group])
      flash[:notice] = "#{t('flash2')}"
      redirect_to [@batch, @exam_group]
    else
      render 'edit'
    end
  end

  def destroy
    @exam_group = ExamGroup.find(params[:id], :include => :exams)
    if @current_user.employee?
      @employee_subjects= @current_user.employee_record.subjects.map { |n| n.id}
      if @employee_subjects.empty? and !@current_user.privileges.map{|p| p.name}.include?("ExaminationControl") and !@current_user.privileges.map{|p| p.name}.include?("EnterResults")
        flash[:notice] = "#{t('flash_msg4')}"
        redirect_to :controller => 'user', :action => 'dashboard'
      end
    end 
    flash[:notice] = "#{t('flash3')}" if @exam_group.destroy
    redirect_to batch_exam_groups_path(@batch)
  end

  def show
    @exam_group = ExamGroup.find(params[:id], :include => :exams)
    if @current_user.employee?
      @user_privileges = @current_user.privileges
      @employee_subjects= @current_user.employee_record.subjects.map { |n| n.id}
      if @employee_subjects.empty? and !@current_user.privileges.map{|p| p.name}.include?("ExaminationControl") and !@current_user.privileges.map{|p| p.name}.include?("EnterResults")
        flash[:notice] = "#{t('flash_msg4')}"
        redirect_to :controller => 'user', :action => 'dashboard'
      end
    end
  end

  private
  def initial_queries
    @batch = Batch.find params[:batch_id], :include => :course unless params[:batch_id].nil?
    @course = @batch.course unless @batch.nil?
  end

  def protect_other_batch_exams
    @user_privileges = @current_user.privileges
    if !@current_user.admin? and !@user_privileges.map{|p| p.name}.include?('ExaminationControl') and !@user_privileges.map{|p| p.name}.include?('EnterResults')
      @user_subjects = @current_user.employee_record.subjects.all(:group => 'batch_id')
      @user_batches = @user_subjects.map{|x|x.batch_id} unless @current_user.employee_record.blank? or @user_subjects.nil?

      unless @user_batches.include?(params[:batch_id].to_i)
        flash[:notice] = "#{t('flash_msg4')}"
        redirect_to :controller => 'user', :action => 'dashboard'
      end
    end
  end
end