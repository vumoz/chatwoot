# frozen_string_literal: true

class Api::V1::Accounts::CustomerEngine::ConnectorsController < Api::V1::Accounts::BaseController
  before_action :authorize_admin!
  before_action :set_connector, only: [:update, :destroy, :sync]

  def index
    connectors = Current.account.customer_engine_connectors.order(:id)
    render json: { data: connectors.as_json(except: %i[access_token]) }
  end

  def create
    connector = Current.account.customer_engine_connectors.new(connector_params)
    connector.save!
    render json: connector.as_json, status: :created
  end

  def update
    @connector.assign_attributes(connector_params)
    @connector.save!
    render json: @connector.as_json
  end

  def destroy
    @connector.destroy!
    head :ok
  end

  def sync
    count = CustomerEngine::ConnectorSyncService.new(@connector).perform
    render json: { synced: count, last_synced_at: @connector.reload.last_synced_at }
  end

  private

  def authorize_admin!
    authorize(Account, :update?)
  end

  def set_connector
    @connector = Current.account.customer_engine_connectors.find(params[:id])
  end

  def connector_params
    params.require(:connector).permit(:name, :provider, :status, settings: {})
  end
end

Api::V1::Accounts::CustomerEngine::ConnectorsController.prepend_mod_with(
  'Api::V1::Accounts::CustomerEngine::ConnectorsController'
)
