# frozen_string_literal: true
module Valkyrie::Persistence::Solr
  class Repository
    attr_reader :models, :connection, :resource_factory
    def initialize(models:, connection:, resource_factory:)
      @models = models
      @connection = connection
      @resource_factory = resource_factory
    end

    def persist
      documents = models.map do |model|
        generate_id(model) if model.id.blank?
        solr_document(model)
      end
      connection.add documents, params: { softCommit: true }
      documents.map do |document|
        resource_factory.to_model(document.stringify_keys)
      end
    end

    def delete
      connection.delete_by_id models.map { |model| "id-#{model.id}" }, params: { softCommit: true }
      models
    end

    def solr_document(model)
      resource_factory.from_model(model).to_h
    end

    def generate_id(model)
      Valkyrie.logger.warn "The Solr adapter is not meant to persist new resources, but is now generating an ID."
      model.id = SecureRandom.uuid
    end
  end
end