require 'hubspot-api-client'

class HubspotService
    attr_reader :contact, :pipeline

    def initialize(contact:)
      @contact = contact.attributes
    end

    def save_lead_info
      return if contact_exists?
      hubspot_contact = create_contact
      deal = create_deal
      company = create_company(contact["email"])
      create_association({from_name: "contact", to_name: "deal", from_id: hubspot_contact.id, to_id: deal.id, type: "contact_to-deal"})
      create_association({from_name: "contact", to_name: "company", from_id: hubspot_contact.id, to_id: company.id, type: "contact_to_company"})
      create_association({from_name: "deal", to_name: "company", from_id: deal.id, to_id: company.id, type: "deal_to_company"})
      create_association({from_name: "deal", to_name: "contact", from_id: deal.id, to_id: hubspot_contact.id, type: "deal_to_contact"})
    end

    private

    def contact_exists?

      search_api = Hubspot.client.crm.contacts.search_api
      results = search_api.do_search(contact_search_request).results
      results.present?
    end

    def get_line_item
      search_api = Hubspot.client.crm.line_items.search_api
      search_api.do_search(line_item_search_request).results
    end

    def get_company(company_domain)
      search_api = Hubspot.client.crm.companies.search_api
      search_api.do_search(company_search_request(company_domain)).results.first
    end

    def create_contact
      contacts_api = Hubspot.client.crm.contacts.basic_api
      contacts_api.create(properties: contact_properties)
    end

    def create_deal
      deals_api = Hubspot.client.crm.deals.basic_api
      deals_api.create(properties: deal_properties)
    end

    def contact_properties
      {
        firstname: contact["name"],
        email: contact["email"],
        contact_message: contact["message"],
        request_type: contact["request_type"],
        utm_campaign: contact["utm_campaign"],
        utm_medium: contact["utm_medium"],
        utm_source: contact["utm_source"],
        gclid: contact["gclid"],
        in_house_developers: contact["in_house_developers"],
        starting_at: contact["starting_at"]
      }
    end

    def deal_properties
      @pipeline = get_pipeline

      {
        dealname: contact["name"].capitalize,
        pipeline: pipeline.id,
        dealstage: get_cold_stage.id
      }
    end

    def get_pipeline
      pipeline_api = Hubspot.client.crm.pipelines.pipelines_api
      pipelines = pipeline_api.get_all("DEAL").results
      pipelines.find { |pipeline| pipeline.label == ENV["HUBSPOT_PIPELINE_LABEL"] }
    end

    def get_cold_stage
      pipeline.stages.find { |stage| stage.label == "Cold" }
    end

    def contact_search_request
      {
        filter_groups: [
          {
            filters: [
              {
                property_name: "email",
                operator: "EQ",
                value: contact["email"]
              }
            ]
          }
        ]
      }
    end

    def company_search_request(company_domain)
      {
        filter_groups: [
          {
            filters: [
              {
                property_name: "domain",
                operator: "EQ",
                value: company_domain
              }
            ]
          }
        ]
      }
    end

    def create_association(properties)
      connection = Hubspot.client.crm.associations.batch_api
      connection.create(
        properties[:from_name], properties[:to_name],
        batch_input_public_association: {
          inputs: [
            {from: {id: properties[:from_id]}, to: {id: properties[:to_id]}, type: properties[:type]}
          ]
        }
      )
    end

    def create_company(email)
      company_domain = email.split("@").last
      existing_company = get_company(company_domain)
      return existing_company if existing_company.present?
      company_name = company_domain.split(".").first
      company = Hubspot.client.crm.companies.basic_api
      company.create(properties: {
        domain: company_domain,
        name: company_name.capitalize
      })
    end
  end