class UserController < ApplicationController
  layout :choose_layout
  before_filter :login_required, :except => [:forgot_password, :login, :set_new_password, :reset_password]
  before_filter :only_admin_allowed, :only => [:edit, :create, :index, :edit_privilege, :user_change_password,:delete,:list_user,:all]
  before_filter :protect_user_data, :only => [:profile, :user_change_password]
  before_filter :check_if_loggedin, :only => [:login]
  #  filter_access_to :edit_privilege
  def choose_layout
    return 'login' if action_name == 'login' or action_name == 'set_new_password'
    return 'forgotpw' if action_name == 'forgot_password'
    return 'dashboard' if action_name == 'dashboard'
    'application'
  end
  
  def all
    @users = User.all
  end
  
  def list_user
    if params[:user_type] == 'Admin'
      @users = User.find(:all, :conditions => {:admin => true}, :order => 'first_name ASC')
      render(:update) do |page|
        page.replace_html 'users', :partial=> 'users'
        page.replace_html 'employee_user', :text => ''
        page.replace_html 'student_user', :text => ''
      end
    elsif params[:user_type] == 'Employee'
      render(:update) do |page|
        hr = Configuration.find_by_config_value("HR")
        unless hr.nil?
          page.replace_html 'employee_user', :partial=> 'employee_user'
          page.replace_html 'users', :text => ''
          page.replace_html 'student_user', :text => ''
        else
          @users = User.find_all_by_employee(1)
          page.replace_html 'users', :partial=> 'users'
          page.replace_html 'employee_user', :text => ''
          page.replace_html 'student_user', :text => ''
        end
      end
    elsif params[:user_type] == 'Student'
      render(:update) do |page|
        page.replace_html 'student_user', :partial=> 'student_user'
        page.replace_html 'users', :text => ''
        page.replace_html 'employee_user', :text => ''
      end
    elsif params[:user_type] == ''
      @users = ""
      render(:update) do |page|
        page.replace_html 'users', :partial=> 'users'
        page.replace_html 'employee_user', :text => ''
        page.replace_html 'student_user', :text => ''
      end
    end
  end

  def list_employee_user
    emp_dept = params[:dept_id]
    @employee = Employee.find_all_by_employee_department_id(emp_dept, :order =>'first_name ASC')
    @users = @employee.collect { |employee| employee.user}
    @users.delete(nil)
    render(:update) {|page| page.replace_html 'users', :partial=> 'users'}
  end

  def list_student_user
    batch = params[:batch_id]
    @student = Student.find_all_by_batch_id(batch, :conditions => { :is_active => true },:order =>'first_name ASC')
    @users = @student.collect { |student| student.user}
    @users.delete(nil)
    render(:update) {|page| page.replace_html 'users', :partial=> 'users'}
  end

  def change_password
    
    if request.post?
      @user = current_user
      if User.authenticate?(@user.username, params[:user][:old_password])
        if params[:user][:new_password] == params[:user][:confirm_password]
          @user.password = params[:user][:new_password]
          @user.update_attributes(:password => @user.password,
            :role => @user.role_name
          )
          flash[:notice] = "#{t('flash9')}"
          redirect_to :action => 'dashboard'
        else
          flash[:warn_notice] = "<p>#{t('flash10')}</p>"
        end
      else
        flash[:warn_notice] = "<p>#{t('flash11')}</p>"
      end
    end
  end

  def user_change_password
    user = User.find_by_username(params[:id])

    if request.post?
      if params[:user][:new_password]=='' and params[:user][:confirm_password]==''
        flash[:warn_notice]= "<p>#{t('flash6')}</p>"
      else
        if params[:user][:new_password] == params[:user][:confirm_password]
          user.password = params[:user][:new_password]
          user.update_attributes(:password => user.password,
            :role => user.role_name
          )
          flash[:notice]= "#{t('flash7')}"
          redirect_to :action=>"edit", :id=>user.username
        else
          flash[:warn_notice] =  "<p>#{t('flash10')}</p>"
        end
      end

      
    end
  end

  def create
    @config = Configuration.available_modules

    @user = User.new(params[:user])
    if request.post?
          
      if @user.save
        flash[:notice] = "#{t('flash17')}"
        redirect_to :controller => 'user', :action => 'edit', :id => @user.username
      else
        flash[:notice] = "#{t('flash16')}"
      end
           
    end
  end

  def delete
    @user = User.find_by_username(params[:id],:conditions=>"admin = 1")
    unless @user.nil?
      if @user.employee_record.nil?
        flash[:notice] = "#{t('flash12')}" if @user.destroy
      end
    end
    redirect_to :controller => 'user'
  end
  
  def dashboard
    @user = current_user
    @config = Configuration.available_modules
    @employee = @user.employee_record if ['employee','admin'].include?(@user.role_name.downcase)
    @student = @user.student_record  if @user.role_name.downcase == 'student'
    @dash_news = News.find(:all, :limit => 5)
  end

  def edit
    @user = User.find_by_username(params[:id])
    @current_user = current_user
    if request.post? and @user.update_attributes(params[:user])
      flash[:notice] = "#{t('flash13')}"
      redirect_to :controller => 'user', :action => 'profile', :id => @user.username
    end
  end

  def forgot_password
    #    flash[:notice]="You do not have permission to access forgot password!"
    #    redirect_to :action=>"login"
    @network_state = Configuration.find_by_config_key("NetworkState")
    if request.post? and params[:reset_password]
      if user = User.find_by_username(params[:reset_password][:username])
        user.reset_password_code = Digest::SHA1.hexdigest( "#{user.email}#{Time.now.to_s.split(//).sort_by {rand}.join}" )
        user.reset_password_code_until = 1.day.from_now
        user.role = user.role_name
        user.save(false)
        url = "#{request.protocol}#{request.host_with_port}"
        UserNotifier.deliver_forgot_password(user,url)
        flash[:notice] = "#{t('flash18')}"
        redirect_to :action => "index"
      else
        flash[:notice] = "#{t('flash19')} #{params[:reset_password][:username]}"
      end
    end
  end

  def login
    @institute = Configuration.find_by_config_key("LogoName")
    if request.post? and params[:user]
      @user = User.new(params[:user])
      user = User.find_by_username @user.username
      if user and User.authenticate?(@user.username, @user.password)
        session[:user_id] = user.id
        flash[:notice] = "#{t('welcome')}, #{user.first_name} #{user.last_name}!"
        redirect_to session[:back_url] || {:controller => 'user', :action => 'dashboard'}
      else
        flash[:notice] = "#{t('login_error_message')}"
      end
    end
  end

  def logout
    Rails.cache.delete("user_main_menu#{session[:user_id]}")
    Rails.cache.delete("user_autocomplete_menu#{session[:user_id]}")
    session[:user_id] = nil
    session[:language] = nil
    flash[:notice] = "#{t('logged_out')}"
    redirect_to :controller => 'user', :action => 'login'
  end

  def profile
    @config = Configuration.available_modules
    @current_user = current_user
    @username = @current_user.username if session[:user_id]
    @user = User.find_by_username(params[:id])
    unless @user.nil?
      @employee = Employee.find_by_employee_number(@user.username)
      @student = Student.find_by_admission_no(@user.username)
    else
      flash[:notice] = "#{t('flash14')}"
      redirect_to :action => 'dashboard'
    end
  end

  def reset_password
    user = User.find_by_reset_password_code(params[:id],:conditions=>"reset_password_code IS NOT NULL")
    if user
      if user.reset_password_code_until > Time.now
        redirect_to :action => 'set_new_password', :id => user.reset_password_code
      else
        flash[:notice] = "#{t('flash1')}"
        redirect_to :action => 'index'
      end
    else
      flash[:notice]= "#{t('flash2')}"
      redirect_to :action => 'index'
    end
  end

  def search_user_ajax
    unless params[:query].nil? or params[:query].empty? or params[:query] == ' '
      if params[:query].length>= 3
        @user = User.first_name_or_last_name_or_username_begins_with params[:query].split
        #      @user = User.find(:all,
        #                :conditions => "(first_name LIKE \"#{params[:query]}%\"
        #                       OR username LIKE \"#{params[:query]}%\"
        #                       OR last_name LIKE \"#{params[:query]}%\"
        #                       OR (concat(first_name, \" \", last_name) LIKE \"#{params[:query]}%\"))",
        #                :order => "role_name asc,first_name asc") unless params[:query] == ''
      else
        @user = User.first_name_or_last_name_or_username_equals params[:query].split
      end
      @user = @user.sort_by { |u1| [u1.role_name,u1.full_name] } unless @user.nil?
    else
      @user = ''
    end
    render :layout => false
  end

  def set_new_password
    if request.post?
      user = User.find_by_reset_password_code(params[:id],:conditions=>"reset_password_code IS NOT NULL")
      if user
        if params[:set_new_password][:new_password] === params[:set_new_password][:confirm_password]
          user.password = params[:set_new_password][:new_password]
          user.update_attributes(:password => user.password, :reset_password_code => nil, :reset_password_code_until => nil, :role => user.role_name)
          user.clear_menu_cache
          #User.update(user.id, :password => params[:set_new_password][:new_password],
          # :reset_password_code => nil, :reset_password_code_until => nil)
          flash[:notice] = "#{t('flash3')}"
          redirect_to :action => 'index'
        else
          flash[:notice] = "#{t('user.flash4')}"
          redirect_to :action => 'set_new_password', :id => user.reset_password_code
        end
      else
        flash[:notice] = "#{t('flash5')}"
        redirect_to :action => 'index'
      end
    end
  end

  def edit_privilege
    @privileges = Privilege.find(:all)
    @user = User.find_by_username(params[:id])
    @finance = Configuration.find_by_config_value("Finance")
    @sms = Configuration.find_by_config_value("SMS")
    @hr = Configuration.find_by_config_value("HR")
    if request.post?
      new_privileges = params[:user][:privilege_ids] if params[:user]
      new_privileges ||= []
      @user.privileges = Privilege.find_all_by_id(new_privileges)
      @user.clear_menu_cache
      flash[:notice] = "#{t('flash15')}"
      redirect_to :action => 'profile',:id => @user.username
    end
  end

  def header_link
    @user = current_user
    #@reminders = @users.check_reminders
    @config = Configuration.available_modules
    @employee = Employee.find_by_employee_number(@user.username)
    @employee ||= Employee.first if current_user.admin?
    @student = Student.find_by_admission_no(@user.username)
    render :partial=>'header_link'
  end
end

