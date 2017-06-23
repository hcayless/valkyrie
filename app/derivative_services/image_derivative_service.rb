# frozen_string_literal: true
class ImageDerivativeService
  class Factory
    attr_reader :adapter, :storage_adapter, :image_config, :use
    def initialize(adapter:, storage_adapter:, image_config: ImageConfig.new(width: 200, height: 150, format: 'jpg', mime_type: 'image/jpeg', output_name: 'thumbnail'), use: [])
      @adapter = adapter
      @storage_adapter = storage_adapter
      @image_config = image_config
      self.use = use
    end

    def use=(use)
      @use = Array(use) + [Valkyrie::Vocab::PCDMUse.ServiceFile]
    end

    def new(file_set)
      ::ImageDerivativeService.new(file_set: file_set, original_file: original_file(file_set), storage_solution: storage_solution, image_config: image_config, use: use)
    end

    def original_file(file_set)
      members(file_set).find { |x| x.use.include?(Valkyrie::Vocab::PCDMUse.OriginalFile) }
    end

    def members(file_set)
      adapter.query_service.find_members(model: file_set)
    end

    def storage_solution
      StorageSolution.new(adapter: adapter, storage_adapter: storage_adapter)
    end

    class ImageConfig < Dry::Struct
      attribute :width, Valkyrie::Types::Int
      attribute :height, Valkyrie::Types::Int
      attribute :format, Valkyrie::Types::String
      attribute :mime_type, Valkyrie::Types::String
      attribute :output_name, Valkyrie::Types::String
    end

    class StorageSolution
      attr_reader :adapter, :storage_adapter
      def initialize(adapter:, storage_adapter:)
        @adapter = adapter
        @storage_adapter = storage_adapter
      end
    end
  end
  attr_reader :file_set, :original_file, :image_config, :use, :storage_solution
  delegate :adapter, :storage_adapter, to: :storage_solution
  delegate :width, :height, :format, :output_name, to: :image_config
  delegate :mime_type, to: :original_file
  delegate :persister, to: :adapter
  def initialize(file_set:, original_file:, storage_solution:, image_config:, use:)
    @file_set = file_set
    @original_file = original_file
    @storage_solution = storage_solution
    @image_config = image_config
    @use = use
  end

  def image_mime_type
    image_config.mime_type
  end

  def create_derivatives
    Hydra::Derivatives::ImageDerivatives.create(filename,
                                                outputs: [{ label: :thumbnail, format: format, size: "#{width}x#{height}>", url: URI("file://#{temporary_output.path}") }])
    file_node = persister.save(model: FileNode.new(use: use, label: output_name, mime_type: image_mime_type))
    file = build_file(file_node)
    file_node.file_identifiers = file.id
    persister.save(model: file_node)
    file_set.member_ids = file_set.member_ids + [file_node.id]
    persister.save(model: file_set)
    file_set
  end

  class IoDecorator < SimpleDelegator
    attr_reader :original_filename
    def initialize(io, original_filename)
      @original_filename = original_filename
      super(io)
    end
  end

  def build_file(file_node)
    file = IoDecorator.new(temporary_output, "#{output_name}.#{format}")
    storage_adapter.upload(file: file, model: file_node)
  end

  def cleanup_derivatives; end

  def filename
    return Pathname.new(file_object.io.path) if file_object.io.respond_to?(:path) && File.exist?(file_object.io.path)
  end

  def file_object
    @file_object ||= Valkyrie::FileRepository.find_by(id: original_file.file_identifiers[0])
  end

  def temporary_output
    @temporary_file ||= Tempfile.new
  end

  def valid?
    mime_type.include?("image/tiff")
  end
end