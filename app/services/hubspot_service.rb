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

      # For type_id values, refer to Hubspot association type definitions
      # https://developers.hubspot.com/docs/api-reference/crm-associations-v4/guide#association-type-id-values
      create_association(from_type: "contacts", to_type: "deals", from_id: hubspot_contact.id, to_id: deal.id, type_id: 4)
      create_association(from_type: "contacts", to_type: "companies", from_id: hubspot_contact.id, to_id: company.id, type_id: 1)
      create_association(from_type: "deals", to_type: "companies", from_id: deal.id, to_id: company.id, type_id: 5)
      create_association(from_type: "deals", to_type: "contacts", from_id: deal.id, to_id: hubspot_contact.id, type_id: 3)
    end

    private

    def contact_exists?
      email = contact["email"].to_s.strip.downcase
      search_api = Hubspot.client.crm.contacts.search_api
      results = search_api.do_search(public_object_search_request: contact_search_request(email)).results
      results.any? { |r| r.properties["email"]&.downcase == email }
    end

    def get_line_item
      search_api = Hubspot.client.crm.line_items.search_api
      search_api.do_search(public_object_search_request: line_item_search_request).results
    end

    def get_company(company_domain)
      search_api = Hubspot.client.crm.companies.search_api
      search_api.do_search(public_object_search_request: company_search_request(company_domain)).results.first
    end

    def create_contact
      contacts_api = Hubspot.client.crm.contacts.basic_api
      contacts_api.create(simple_public_object_input: contact_properties)
    end

    def create_deal
      deals_api = Hubspot.client.crm.deals.basic_api
      deals_api.create(simple_public_object_input: deal_properties)
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
      pipelines = pipeline_api.get_all(object_type: "deals").results
      pipelines.find { |pipeline| pipeline.label == ENV["HUBSPOT_PIPELINE_LABEL"] }
    end

    def get_cold_stage
      pipeline.stages.find { |stage| stage.label == "Cold" }
    end

    def contact_search_request(email)
      {
        filterGroups: [
          {
            filters: [
              {
                propertyName: "email",
                operator: "EQ",
                value: email
              }
            ]
          }
        ],
        properties: ["email", "firstname"]
      }
    end

    def company_search_request(company_domain)
      {
        filterGroups: [
          {
            filters: [
              {
                propertyName: "domain",
                operator: "EQ",
                value: company_domain
              }
            ]
          }
        ],
        properties: ["domain", "name"]
      }
    end

    def create_association(from_type:, to_type:, from_id:, to_id:, type_id:)
      batch_api = Hubspot.client.crm.associations.v4.batch_api
      result = batch_api.create(
        from_object_type: from_type,
        to_object_type: to_type,
        batch_input_public_association_multi_post: {
          inputs: [
            {
              from: { id: from_id },
              to: { id: to_id },
              types: [{ associationCategory: "HUBSPOT_DEFINED", associationTypeId: type_id }]
            }
          ]
        }
      )
    end

    def create_company(email)
      company_domain = email.split("@").last
      existing_company = get_company(company_domain)
      return existing_company if existing_company.present?
      company_name = company_domain.split(".").first
      company_api = Hubspot.client.crm.companies.basic_api
      company_api.create(properties: {
        domain: company_domain,
        name: company_name.capitalize
      })
    end
  end