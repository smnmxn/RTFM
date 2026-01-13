class AddContextualQuestionsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :contextual_questions, :json
  end
end
