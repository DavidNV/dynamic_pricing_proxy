class Api::V1::PricingController < ApplicationController
  VALID_PERIODS = %w[Summer Autumn Winter Spring].freeze
  VALID_HOTELS  = %w[FloatingPointResort GitawayHotel RecursionRetreat].freeze
  VALID_ROOMS   = %w[SingletonRoom BooleanTwin RestfulKing].freeze

  before_action :validate_single_params, only: :index
  before_action :validate_batch_params,  only: :create

  def index
    service = Api::V1::PricingService.new(
      attributes:      [{ period: params[:period], hotel: params[:hotel], room: params[:room] }],
      result_extractor: SingleRateExtractor.new(period: params[:period], hotel: params[:hotel], room: params[:room])
    )
    service.run
    render_service_response(service)
  end

  def create
    attributes = params[:attributes].map do |attr|
      { period: attr[:period], hotel: attr[:hotel], room: attr[:room] }
    end

    service = Api::V1::PricingService.new(
      attributes:,
      result_extractor: BatchRateExtractor.new
    )
    service.run
    render_service_response(service, batch: true)
  end

  private

  def render_service_response(service, batch: false)
    if service.valid?
      if batch
        render json: { rates: service.result }
      else
        render json: service.result
      end
    else
      render json: { error: service.errors.join(", ") }, status: error_status(service.errors)
    end
  end

  def error_status(errors)
    message = errors.join(" ")
    if message.include?("temporarily unavailable")
      :service_unavailable      # 503
    elsif message.include?("not found")
      :not_found                # 404
    elsif message.include?("timed out") || message.include?("unavailable") || message.include?("invalid response") || message.include?("unexpected response")
      :bad_gateway              # 502
    else
      :bad_request              # 400
    end
  end

  def validate_single_params
    unless params[:period].present? && params[:hotel].present? && params[:room].present?
      return render json: { error: "Missing required parameters: period, hotel, room" }, status: :bad_request
    end

    unless VALID_PERIODS.include?(params[:period])
      return render json: { error: "Invalid period. Must be one of: #{VALID_PERIODS.join(', ')}" }, status: :bad_request
    end

    unless VALID_HOTELS.include?(params[:hotel])
      return render json: { error: "Invalid hotel. Must be one of: #{VALID_HOTELS.join(', ')}" }, status: :bad_request
    end

    unless VALID_ROOMS.include?(params[:room])
      return render json: { error: "Invalid room. Must be one of: #{VALID_ROOMS.join(', ')}" }, status: :bad_request
    end
  end

  def validate_batch_params
    unless params[:attributes].present?
      return render json: { error: "Missing required parameter: attributes" }, status: :bad_request
    end

    unless params[:attributes].is_a?(Array)
      return render json: { error: "attributes must be an array" }, status: :bad_request
    end

    params[:attributes].each_with_index do |attr, index|
      unless VALID_PERIODS.include?(attr[:period])
        return render json: { error: "Invalid period at index #{index}. Must be one of: #{VALID_PERIODS.join(', ')}" }, status: :bad_request
      end

      unless VALID_HOTELS.include?(attr[:hotel])
        return render json: { error: "Invalid hotel at index #{index}. Must be one of: #{VALID_HOTELS.join(', ')}" }, status: :bad_request
      end

      unless VALID_ROOMS.include?(attr[:room])
        return render json: { error: "Invalid room at index #{index}. Must be one of: #{VALID_ROOMS.join(', ')}" }, status: :bad_request
      end
    end
  end

  def validate_attribute(attr, index: nil)
    prefix = index ? "at index #{index} " : ""

    unless VALID_PERIODS.include?(attr[:period])
      render json: { error: "Invalid period #{prefix}. Must be one of: #{VALID_PERIODS.join(', ')}" }, status: :bad_request
      return false
    end

    unless VALID_HOTELS.include?(attr[:hotel])
      render json: { error: "Invalid hotel #{prefix}. Must be one of: #{VALID_HOTELS.join(', ')}" }, status: :bad_request
      return false
    end

    unless VALID_ROOMS.include?(attr[:room])
      render json: { error: "Invalid room #{prefix}. Must be one of: #{VALID_ROOMS.join(', ')}" }, status: :bad_request
      return false
    end

    true
  end
end
