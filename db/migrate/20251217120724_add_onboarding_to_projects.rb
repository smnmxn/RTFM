class AddOnboardingToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :onboarding_step, :string
    add_column :projects, :onboarding_started_at, :datetime
    add_index :projects, :onboarding_step
  end
end
