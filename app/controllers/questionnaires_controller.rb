class QuestionnairesController < ApplicationController
  include AuthorizationHelper

  # Controller for Questionnaire objects
  # A Questionnaire can be of several types (QuestionnaireType)
  # Each Questionnaire contains zero or more questions (Question)
  # Generally a questionnaire is associated with an assignment (Assignment)

  # before_action :authorize

  # Check role access for edit questionnaire
  def action_allowed?
    case params[:action]
    when 'edit'
      @questionnaire = Questionnaire.find(params[:id])
      current_user_has_admin_privileges? ||
        (current_user_is_a?('Instructor') && current_user_id?(@questionnaire.try(:instructor_id))) ||
        (current_user_is_a?('Teaching Assistant') && session[:user].instructor_id == @questionnaire.try(:instructor_id))
    else
      current_user_has_student_privileges?
    end
  end

  # Create a clone of the given questionnaire, copying all associated
  # questions. The name and creator are updated.
  #working fine verified
  def copy
    instructor_id = session[:user].instructor_id
    @questionnaire = Questionnaire.copy_questionnaire_details(params, instructor_id)
    p_folder = TreeFolder.find_by(name: @questionnaire.display_type)
    parent = FolderNode.find_by(node_object_id: p_folder.id)
    QuestionnaireNode.find_or_create_by(parent_id: parent.id, node_object_id: @questionnaire.id)
    undo_link("Copy of questionnaire #{@questionnaire.name} has been created successfully.")
    redirect_to controller: 'questionnaires', action: 'view', id: @questionnaire.id
  rescue StandardError
    flash[:error] = 'The questionnaire was not able to be copied. Please check the original course for missing information.' + $ERROR_INFO.to_s
    redirect_to action: 'list', controller: 'tree_display'
  end

  # /questionnaires/view?id=115
  def view
    begin
      @questionnaire = Questionnaire.find(params[:id])
      render json: @questionnaire
    rescue
      msg = "No such Questionnaire exists."
      render json: msg
    end
  end

  # new?model=ReviewQuestionnaire&private=1
  def new
    puts "IN NEW!"
    begin
      @questionnaire = Object.const_get(params[:model].split.join).new if Questionnaire::QUESTIONNAIRE_TYPES.include? params[:model].split.join
      msg = 'A rubric or survey must have a title.'
      render json: msg
    rescue StandardError
      msg = $ERROR_INFO
      render json: msg
    end
  end

  # /review_questionnaires
  def create
    puts "IN CREATE!"
    puts params.inspect
    if params[:questionnaire][:name].blank?
      redirect_to controller: 'questionnaires', action: 'new', model: params[:questionnaire][:type], private: params[:questionnaire][:private]
    else
      questionnaire_private = params[:questionnaire][:private] == 'true'
      display_type = params[:questionnaire][:type].split('Questionnaire')[0]
      begin
        @questionnaire = Object.const_get(params[:questionnaire][:type]).new if Questionnaire::QUESTIONNAIRE_TYPES.include? params[:questionnaire][:type]
      rescue StandardError
        msg = $ERROR_INFO
        render json: msg
      end
      begin
        @questionnaire.private = questionnaire_private
        @questionnaire.name = params[:questionnaire][:name]
        @questionnaire.instructor_id = 6 # session[:user].id
        @questionnaire.min_question_score = params[:questionnaire][:min_question_score]
        @questionnaire.max_question_score = params[:questionnaire][:max_question_score]
        @questionnaire.type = params[:questionnaire][:type]
        # Zhewei: Right now, the display_type in 'questionnaires' table and name in 'tree_folders' table are not consistent.
        # In the future, we need to write migration files to make them consistency.
        # E1903 : We are not sure of other type of cases, so have added a if statement. If there are only 5 cases, remove the if statement
        if %w[AuthorFeedback CourseSurvey TeammateReview GlobalSurvey AssignmentSurvey BookmarkRating].include?(display_type)
          display_type = (display_type.split(/(?=[A-Z])/)).join('%')
        end
        @questionnaire.display_type = display_type
        @questionnaire.instruction_loc = Questionnaire::DEFAULT_QUESTIONNAIRE_URL
        @questionnaire.save
        # Create node
        tree_folder = TreeFolder.where(['name like ?', @questionnaire.display_type]).first
        parent = FolderNode.find_by(node_object_id: tree_folder.id)
        QuestionnaireNode.create(parent_id: parent.id, node_object_id: @questionnaire.id, type: 'QuestionnaireNode')
        msg = 'You have successfully created a questionnaire!'
        render json: msg
      rescue StandardError
        msg = $ERROR_INFO
        render json: msg
      end
      # redirect_to controller: 'questionnaires', action: 'view', id: @questionnaire.id
    end
  end

  # Edit a questionnaire
  #working fine verified
  def edit
    @questionnaire = Questionnaire.find(params[:id])
    redirect_to Questionnaire if @questionnaire.nil?
    session[:return_to] = request.original_url
  end

  
  #code is not working fine, want to confirm with ankur whether we need to call this method as it is part of render instead save_all_questions is used
  def update
    # If 'Add' or 'Edit/View advice' is clicked, redirect appropriately
      @questionnaire = Questionnaire.find(params[:id])
      begin
        # Save questionnaire information
        @questionnaire.update_attributes(questionnaire_params)
        puts(questionnaire_params)
        # Save all questions
        unless params[:question].nil?
          params[:question].each_pair do |k, v|
            @question = Question.find(k)
            # example of 'v' value
            # {"seq"=>"1.0", "txt"=>"WOW", "weight"=>"1", "size"=>"50,3", "max_label"=>"Strong agree", "min_label"=>"Not agree"}
            v.each_pair do |key, value|
              @question.send(key + '=', value) unless @question.send(key) == value
            end
            @question.save
          end
        end
        flash[:success] = 'The questionnaire has been successfully updated!'
      rescue StandardError
        flash[:error] = $ERROR_INFO
      end
      redirect_to action: 'edit', id: @questionnaire.id.to_s.to_sym

  end

  # Remove a given questionnaire
  #working fine verified
  def delete
    @questionnaire = Questionnaire.find(params[:id])
    if @questionnaire
      begin
        name = @questionnaire.name
        # if this rubric is used by some assignment, flash error
        unless @questionnaire.assignments.empty?
          raise "The assignment <b>#{@questionnaire.assignments.first.try(:name)}</b> uses this questionnaire. Are sure you want to delete the assignment?"
        end

        questions = @questionnaire.questions
        # if this rubric had some answers, flash error
        questions.each do |question|
          raise 'There are responses based on this rubric, we suggest you do not delete it.' unless question.answers.empty?
        end
        questions.each do |question|
          advices = question.question_advices
          advices.each(&:delete)
          question.delete
        end
        questionnaire_node = @questionnaire.questionnaire_node
        questionnaire_node.delete
        @questionnaire.delete
        undo_link("The questionnaire \"#{name}\" has been successfully deleted.")
      rescue StandardError => e
        flash[:error] = e.message
      end
    end
    redirect_to action: 'list', controller: 'tree_display'
  end

  # Toggle the access permission for this assignment from public to private, or vice versa
  def toggle_access
    @questionnaire = Questionnaire.find(params[:id])
    @questionnaire.private = !@questionnaire.private
    @questionnaire.save
    @access = @questionnaire.private == true ? 'private' : 'public'
    undo_link("The questionnaire \"#{@questionnaire.name}\" has been successfully made #{@access}. ")
    redirect_to controller: 'tree_display', action: 'list'
  end

  private
  def questionnaire_params
    params.permit(:name, :instructor_id, :private, :min_question_score,
                                          :max_question_score, :type, :display_type, :instruction_loc)
  end

  def question_params
    params.require(:question).permit(:txt, :weight, :questionnaire_id, :seq, :type, :size,
                                     :alternatives, :break_before, :max_label, :min_label)
  end
end
