# frozen_string_literal: true

class AddOrderContextReferences < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :support_issue_id, :string
    add_column :orders, :support_issue_key, :string
    add_column :orders, :trace_id, :string
  end
end
