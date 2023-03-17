RSpec.describe QuestionsController, type: :controller do
  describe "#index" do
  context "when there are questions available" do
  let!(:questions) { create_list(:question, 5, questionnaire: questionnaire) }
  let!(:questionnaire) do
      Questionnaire.create(id: 1, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
    end


  before { get :index }

  it "returns http success" do
  expect(response).to have_http_status(:success)
  end

  it "assigns @questions" do
  expect(assigns(:questions)).to match_array(questions)
  end

  it "returns JSON of questions" do
  questions_json = JSON.parse(response.body)
  expect(questions_json.size).to eq(5)
  expect(questions_json.first["id"]).to eq(questions.first.id)
  expect(questions_json.last["id"]).to eq(questions.last.id)
  end
  end

  context "when there are no questions available" do
  before { get :index }

  it "returns http success" do
  expect(response).to have_http_status(:success)
  end

  it "assigns @questions as an empty array" do
  expect(assigns(:questions)).to eq([])
  end

  it "returns an empty JSON array" do
  questions_json = JSON.parse(response.body)
  expect(questions_json).to eq([])
  end
  end

  context "when an error occurs" do
  before do
  allow(Question).to receive(:paginate).and_raise("Something went wrong")
  get :index
  end

  it "returns http status not found" do
  expect(response).to have_http_status(:not_found)
  end

  it "returns the error message as JSON" do
      expect(response.body).to eq("\"Something went wrong\"")

  end
  end

  end

  describe "GET #show" do
  context "when the question exists" do
  let!(:question) { create(:question, id: 1) }
  
  before do
    get :show, params: { id: question.id }
  end

  it "returns http success" do
    expect(response).to have_http_status(:success)
  end

  it "returns the question as JSON" do
    expect(response.body).to eq(question.to_json)
  end
end

context "when the question does not exist" do
  before do
    get :show, params: { id: 1 }
  end

  it "returns http not found" do
    expect(response).to have_http_status(:not_found)
  end

  it "returns an error message as JSON" do
    expect(response.body).to eq("No such Question exists.")
  end
end
end

describe "POST #create" do

let!(:questionnaire) do
  Questionnaire.create(id: 1, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
end

let(:params) do
  {
  id: questionnaire.id,
  
  question: {
      txt: "This is a test",
      weight: 1,
      questionnaire_id: questionnaire.id,
      seq: "9.0",
      break_before: true,
      type: "Dropdown"
  }
  }
  
  end
context "when successful" do
  it "creates a new question and returns a success message" do
    expect do
      post :create, params: params
    end.to change(Question, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("You have successfully added a new question.")
  end
end

context "when an error occurs" do
  before do
    allow_any_instance_of(Question).to receive(:save).and_raise(StandardError)
    post :create, params: params
  end

  it "returns http status not found" do
    expect(response).to have_http_status(:not_found)
  end

  it "returns the error message as JSON" do
    expect(response.body).to eq("\"StandardError\"")
  end
end
end

describe "DELETE #destroy" do
let!(:questionnaire) { create(:questionnaire) }
let!(:question) { create(:question, questionnaire_id: questionnaire.id) }

context "when question is found and deleted successfully" do
it "deletes the question" do
  expect {
    delete :destroy, params: { id: question.id }
  }.to change { Question.count }.by(-1)
end

it "returns http success" do
  delete :destroy, params: { id: question.id }
  expect(response).to have_http_status(:success)
end

it "returns success message as JSON" do
  delete :destroy, params: { id: question.id }
  expect(response.body).to eq("You have successfully deleted the question!")
end
end

context "when an error occurs" do
before do
  allow(Question).to receive(:find).and_raise("Something went wrong")
  delete :destroy, params: { id: question.id }
end

it "returns http status not found" do
  expect(response).to have_http_status(:not_found)
end

it "returns the error message as JSON" do
  expect(response.body).to eq("\"Something went wrong\"")
end
end
end

describe "GET #types" do
  it "returns a JSON list of question types" do
    create(:question, type: "ScoredQuestion")
    create(:question, type: "Criterion")
    create(:question, type: "Cake")

    get :types
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to eq("application/json")

    json_response = JSON.parse(response.body)
    expect(json_response).to match_array(["ScoredQuestion", "Criterion", "Cake"])
  end
end
end
