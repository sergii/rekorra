# frozen_string_literal: true

class AddTicketContextReferences < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :support_issue_id, :string
    add_column :tickets, :support_issue_key, :string
    add_column :tickets, :trace_id, :string
  end
end
