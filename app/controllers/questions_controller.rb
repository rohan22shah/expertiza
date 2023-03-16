class QuestionsController < ApplicationController
  include AuthorizationHelper
  skip_before_action :verify_authenticity_token
  # A question is a single entry within a questionnaire
  # Questions provide a way of scoring an object
  # based on either a numeric value or a true/false
  # state.

  # Default action, same as list
  def index
    begin
      @questions = Question.paginate(page: params[:page], per_page: 10)
      respond_to do |format|
        format.json { render json: @questions, status: :ok }
        format.html { render action: 'list' }
      end
    rescue StandardError
      msg = $ERROR_INFO
      render json: msg
    end
  end

  def action_allowed?
    current_user_has_ta_privileges?
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify method: :post, only: %i[destroy create update],
         redirect_to: { action: :list }

  # List all questions in paginated view
  def list
    @questions = Question.paginate(page: params[:page], per_page: 10)
  end

  # Display a given question
  def show
    puts "show_question"
    @question = Question.find(params[:id])
  end

  # Provide the user with the ability to define
  # a new question
  def new
    puts "question_new"
    @question = Question.new
  end

  # Save a question created by the user
  # follows from new
  def create
    puts "question_create"
    @question = Question.new(question_params[:question])
    if @question.save
      flash[:notice] = 'The question was successfully created.'
      redirect_to action: 'list'
    else
      render action: 'new'
    end
  end

  # edit an existing question
  def edit
    puts "question_edit"
    @question = Question.find(params[:id])
  end

  # save the update to an existing question
  # follows from edit
  def update
    puts "question_edit"
    @question = Question.find(question_params[:id])
    if @question.update_attributes(question_params[:question])
      flash[:notice] = 'The question was successfully updated.'
      redirect_to action: 'show', id: @question
    else
      render action: 'edit'
    end
  end

  # Remove question from database and
  # return to list
  def destroy
    puts "question_destroy"
    question = Question.find(params[:id])
    questionnaire_id = question.questionnaire_id

    if AnswerHelper.check_and_delete_responses(questionnaire_id)
      msg = 'You have successfully deleted the question. Any existing reviews for the questionnaire have been deleted!'
    else
      msg = 'You have successfully deleted the question!'
    end

    begin
      question.destroy
      render json: msg
    rescue StandardError
      render json: $ERROR_INFO
    end
    redirect_to edit_questionnaire_path(questionnaire_id.to_s.to_sym)
  end

  # Zhewei: This method is used to add new questions when editing questionnaire.
  def add_new_questions
    questionnaire_id = params[:id] unless params[:id].nil?
    # If the questionnaire is being used in the active period of an assignment, delete existing responses before adding new questions
    if AnswerHelper.check_and_delete_responses(questionnaire_id)
      flash[:success] = 'You have successfully added a new question. Any existing reviews for the questionnaire have been deleted!'
    else
      flash[:success] = 'You have successfully added a new question.'
    end

    num_of_existed_questions = Questionnaire.find(questionnaire_id).questions.size
    ((num_of_existed_questions + 1)..(num_of_existed_questions + params[:question][:total_num].to_i)).each do |i|
      question = Object.const_get(params[:question][:type]).create(txt: '', questionnaire_id: questionnaire_id, seq: i, type: params[:question][:type], break_before: true)
      if question.is_a? ScoredQuestion
        question.weight = params[:question][:weight]
        question.max_label = 'Strongly agree'
        question.min_label = 'Strongly disagree'
      end

      question.size = '50, 3' if question.is_a? Criterion
      question.size = '50, 3' if question.is_a? Cake
      question.alternatives = '0|1|2|3|4|5' if question.is_a? Dropdown
      question.size = '60, 5' if question.is_a? TextArea
      question.size = '30' if question.is_a? TextField

      begin
        question.save
      rescue StandardError
        flash[:error] = $ERROR_INFO
      end
    end
    redirect_to edit_questionnaire_path(questionnaire_id.to_sym)
  end

  # required for answer tagging
  def types
    types = Question.distinct.pluck(:type)
    render json: types.to_a
  end

  private

  def question_params
    params.permit(:id, :question)
  end
end
