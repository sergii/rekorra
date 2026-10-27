# frozen_string_literal: true

class AddJobProvider < ActiveRecord::Migration[8.0]
  def change
    add_column :demo_job_links, :provider, :string, default: "solid_queue", null: false
    add_column :demo_job_links, :queue_name, :string, default: "default", null: false
    add_index :demo_job_links, %i[order_id provider]
  end
end
