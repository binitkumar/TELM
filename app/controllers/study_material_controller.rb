class StudyMaterialController < ApplicationController
	def index
		@batches = Batch.active
	end
	
	def list_uploads_by_course
		@students = Student.find_all_by_batch_id(params[:batch_id], :order => 'first_name ASC')
		render(:update) { |page| page.replace_html 'students', :partial => 'uploads_by_course' }
	end
end
