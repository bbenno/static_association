require "static_association/version"
require "active_support/concern"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/inflections"

module StaticAssociation
  extend ActiveSupport::Concern

  class DuplicateID < StandardError; end

  class RecordNotFound < StandardError; end

  class UnknownAttributeReference < StandardError; end

  attr_reader :id

  private

  def initialize(id)
    @id = id
  end

  module ClassMethods
    include Enumerable

    delegate :each, to: :all

    def index
      @index ||= {}.with_indifferent_access
    end

    def all
      index.values
    end

    def find(id)
      find_by_id(id) or raise RecordNotFound
    end

    def find_by_id(id)
      index[id]
    end

    def where(id: [])
      all.select { |record| id.include?(record.id) }
    end

    def pluck(attr)
      raise UnknownAttributeReference unless method_defined? attr
      all.map(&:"#{attr}")
    end

    def record(settings, &block)
      settings.assert_valid_keys(:id)
      id = settings.fetch(:id)
      raise DuplicateID if index.has_key?(id)
      record = new(id)
      record.instance_exec(record, &block) if block
      index[id] = record
    end
  end

  module AssociationHelpers
    def belongs_to_static(name, opts = {})
      class_name = opts.fetch(:class_name, name.to_s.camelize)
      foreign_key_name = opts.fetch(:foreign_key, "#{name}_id")

      send(:define_method, name) do
        foreign_key = read_attribute(foreign_key_name)
        class_name.constantize.find_by_id(foreign_key)
      end

      send(:define_method, "#{name}=") do |assoc|
        write_attribute(foreign_key_name, assoc&.id)
      end
    end
  end
end
