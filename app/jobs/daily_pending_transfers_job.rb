class DailyPendingTransfersJob < ApplicationJob
  queue_as :default

  def perform
    Schedule.find_each do |schedule|
      schedule.create_pending_transfers
    end
  end
end
