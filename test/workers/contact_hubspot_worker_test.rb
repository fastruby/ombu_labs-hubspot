require 'minitest/autorun'

class Contact
  attr_accessor :email, :hubspot_notified_at, :id

  def self.find
  end

  def update_column(attr, value)
      self.hubspot_notified_at = value
  end
end

describe ContactHubspotWorker do 
  describe "perform" do
    describe "when email_sent_at is blank"  do

      it 'sends the contact and updates the timestamp' do
      contact = Contact.new
      hubspot_service = Minitest::Mock.new
      hubspot_service.expect :save_lead_info, true

        Contact.stub(:find, contact) do
          HubspotService.stub(:new, hubspot_service) do
            ContactHubspotWorker.new.perform(contact.id)
          
        end
      end
      _(contact.hubspot_notified_at).wont_be_nil 
      end
    end
  end
end