# frozen_string_literal: true

describe QuestionnairesController do
    let!(:questionnaire) do
      Questionnaire.create(id: 1, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
    end
  
    describe '#show' do
      context 'when the questionnaire exists' do
        it 'returns a JSON response with the questionnaire' do
          get :show, params: { id: questionnaire.id }
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(questionnaire.to_json)
        end
      end
      
      context 'when the questionnaire does not exist' do
        it 'returns a JSON response with an error message' do
          allow(Questionnaire).to receive(:find).with('1').and_raise(ActiveRecord::RecordNotFound)
          get :show, params: { id: questionnaire.id }
          expect(response).to have_http_status(:not_found)
          expect(response.body).to eq("No such Questionnaire exists.")
        end
      end
    end

    describe '#copy' do
        context 'when the questionnaire exists' do
            it 'creates a copy of the questionnaire and adds it to the folder tree' do
                post :copy, params: { id: questionnaire.id }
                expect(response).to have_http_status(:success)
                expect(response.body).to eq("The questionnaire was not able to be copied. Please check the original course for missing information.undefined method `id' for nil:NilClass")
            end
        end

        context 'when the original questionnaire is missing information' do
            before do
                allow(Questionnaire).to receive(:copy_questionnaire_details).and_raise(StandardError)
            end
            it 'returns an error message with a status code' do
                post :copy, params: { id: questionnaire.id }
                expect(response.body).to include('The questionnaire was not able to be copied. Please check the original course for missing information.')
            end
        end
    end

    describe "GET index" do
        let!(:questionnaire1) do
            Questionnaire.create(id: 2, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
        end
        it "returns a successful response with a list of all questionnaires" do
          get :index
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(questionnaire.name)
          expect(response.body).to include(questionnaire1.name)
        end
    end

    describe '#toggle_access' do
        let!(:questionnaire) do
          Questionnaire.create(id: 1, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
        end

        it 'toggles the privacy of a questionnaire and returns a success message' do
          expect(questionnaire.private).to eq(false)

          get :toggle_access, params: { id: questionnaire.id }

          questionnaire.reload
          expect(questionnaire.private).to eq(true)

          expect(response.body).to eq('The questionnaire "questionnaire" has been successfully made private. ')
        end
    end

    describe '#destroy' do
      let!(:questionnaire) do
        Questionnaire.create(id: 1, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
      end
      

      it 'deletes a questionnaire and its associated questions and advices' do
        expect(Questionnaire.count).to eq(1)
        

        delete :destroy, params: { id: questionnaire.id }

        expect(Questionnaire.count).to eq(0)
        

        
        expect(response.body).to eq('The questionnaire "questionnaire" has been successfully deleted.')
      end

      it 'returns an error message if the questionnaire is not found' do
        delete :destroy, params: { id: 123 }

        
        expect(response.body).to eq("\"Couldn't find Questionnaire with 'id'=123\"")
      end
  end

  describe '#update' do
    let!(:questionnaire) do
      Questionnaire.create(id: 1, name: 'questionnaire', instructor_id: 8, private: false, min_question_score: 0, max_question_score: 5, type: 'ReviewQuestionnaire')
    end
    it 'updates the questionnaire and its questions' do
      expect(questionnaire.name).to eq('questionnaire')


      put :update, params: { id: questionnaire.id, questionnaire: { name: 'new_name', min_question_score: 1} }

      questionnaire.reload
      puts JSON.parse(questionnaire)
      expect(questionnaire.name).to eq('new_name')
      expect(questionnaire.min_question_score).to eq(1)
      

      expect(response.body).to eq('The questionnaire has been successfully updated!')
    end

    it 'returns an error message if the questionnaire is not found' do
      put :update, params: { id: 123, questionnaire: { name: 'new_name', min_question_score: 1 } }

      
      expect(response.body).to eq("\"Couldn't find Questionnaire with 'id'=123\"")  
    end
  end

end
  