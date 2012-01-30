class StudyMaterialController < ApplicationController
	def index
		@batches = Batch.active
	end
end
