require 'http'
require 'active_support/core_ext/object/blank'

class HTTP::MimeType::JSON
  def decode(str)
    ::JSON.parse(str, symbolize_names: true)
  end
end

class Revo::LoansApi::Client
  attr_reader :session_token, :loan_request_token

  Result = Struct.new(:success?, :response, keyword_init: true)

  def initialize(
    base_url:,
    login: nil,
    password: nil,
    session_token: nil,
    application_source: nil
  )
    @base_url = base_url
    @login = login
    @password = password
    @session_token = session_token
    @application_source = application_source
  end

  def create_session
    make_request(
      :post, 'sessions',
      params: { user: { login: login, password: password } }
    ).tap do |result|
      @session_token = result.response.dig(:user, :authentication_token) if result&.success?
    end
  end

  def create_loan_request(options)
    response = make_request(
      :post,
      'loan_requests',
      params: loan_request_params(options)
    )
    return response unless response.success?

    @loan_request_token = response.response.dig(:loan_request, :token)
    terms = loan_request_terms
    return terms unless terms.success?

    Result.new(success?: true,
               response: {
                 token: loan_request_token,
                 insurance_available: response.response.dig(:loan_request, :insurance_available),
                 terms: terms.response[:loan_request]
               })
  end

  def update_loan_request(token:, options:)
    update_params = { loan_request: options }
    response = make_request(
      :put,
      "loan_requests/#{token}",
      params: update_params
    )

    return response unless response.success?

    @loan_request_token = token
    terms = loan_request_terms
    return terms unless terms.success?

    Result.new(
      success?: true,
      response: {
        terms: terms.response[:loan_request]
      }
    )
  end

  def get_loan_request_info(token:, amount:)
    result = make_request(:get, "loan_requests/#{token}?amount=#{amount}")

    result.success? ? result.response[:loan_request] : []
  end

  def get_loan_request_attributes(token:)
    result = make_request(:get, "loan_requests/#{token}")

    result.success? ? result.response[:loan_request_attributes] : []
  end

  # prerequisite: a client with the LR's phone number should already exist
  def document(token:, type:, format: 'html')
    make_request(:get, "loan_requests/#{token}/documents/#{type}.#{format}")
  end

  def send_loan_confirmation_message(token:)
    make_request(:post, "loan_requests/#{token}/client/confirmation")
  end

  def complete_loan_request(token:, code:)
    make_request(
      :post,
      "loan_requests/#{token}/confirmation",
      params: { code: code }
    )
  end

  def create_loan(token:, term_id:)
    make_request(
      :post,
      "loan_requests/#{token}/loan",
      params: { term_id: term_id },
      headers: { 'Application-Source': application_source }
    )
  end

  def finalize_loan(token:, code:, sms_info: '0', skip_confirmation: false)
    loan_params = {
      agree_processing: '1',
      confirmation_code: code,
      agree_sms_info: sms_info
    }

    if skip_confirmation
      loan_params[:skip_confirmation] = true
      loan_params.delete(:confirmation_code)
    end

    make_request(
      :post,
      "loan_requests/#{token}/loan/finalization",
      params: { loan: loan_params }
    )
  end

  def confirm_loan(token:, bill:)
    response = make_request(
      :put,
      "loan_requests/#{token}/loan/bill",
      params: { loan: { bill: bill } }
    )

    return response unless response.success?

    Result.new(success?: true, response: response.response)
  end

  # returns
  def orders(store_id:, filters: {})
    make_request(
      :get,
      'orders',
      params: { store_id: store_id, filters: filters }
    )
  end

  def send_return_confirmation_code(order_id:)
    make_request(:post, "orders/#{order_id}/send_return_confirmation_code")
  end

  def create_return(order_id:, code:, amount:, store_id:)
    params = {
      return: {
        order_id: order_id,
        confirmation_code: code,
        amount: amount,
        store_id: store_id
      }
    }
    make_request(:post, 'returns', params: params)
  end

  def confirm_return(return_id:)
    make_request(:post, "returns/#{return_id}/confirm")
  end

  def cancel_return(return_id:)
    make_request(:post, "returns/#{return_id}/cancel")
  end

  def start_self_registration(token:, mobile_phone:, skip_message: false)
    make_request(
      :post,
      "loan_requests/#{token}/client/self_registration",
      params: { mobile_phone: mobile_phone, skip_message: skip_message }
    )
  end

  def check_client_code(token:, code:)
    make_request(
      :post,
      "loan_requests/#{token}/client/check_code",
      params: { code: code }
    )
  end

  def create_client(token:, client_params:, provider_data: {})
    make_request(
      :post,
      "loan_requests/#{token}/client",
      params: { client: client_params, provider_data: provider_data }
    )
  end

  def update_client(id:, client_params:)
    make_request(:patch, "clients/#{id}", params: { client: client_params })
  end

  def get_client(guid:)
    make_request(:get, "clients/#{guid}")
  end

  def create_virtual_card(token:, term_id:)
    make_request(
      :post,
      "loan_requests/#{token}/virtual_card",
      params: { term_id: term_id },
      headers: { 'Application-Source': application_source }
    )
  end

  def create_card_loan(token:, term_id:)
    make_request(
      :post,
      "loan_requests/#{token}/card_loan",
      params: { term_id: term_id },
      headers: { 'Application-Source': application_source }
    )
  end

  def send_billing_shift_confirmation_code(client_id:)
    make_request(:post, "clients/#{client_id}/billing_shift")
  end

  def billing_shift_info(client_id:)
    make_request(:get, "clients/#{client_id}/billing_shift/info")
  end

  def confirm_billing_shift(client_id:, code:, billing_chain:)
    make_request(
      :post,
      "clients/#{client_id}/billing_shift/confirmation",
      params: { code: code, billing_chain: billing_chain }
    )
  end

  def increase_client_limit(client_id:, amount:)
    make_request(
      :patch,
      "clients/#{client_id}/limit",
      params: { amount: amount }
    )
  end

  def client_loan_documents(client_id:, loan_application_id:)
    make_request(:get, "clients/#{client_id}/loans/#{loan_application_id}")
  end

  def get_client_additional_services(client_id:)
    make_request(:get, "clients/#{client_id}/additional_services")
  end

  def update_client_additional_services(client_id:, additional_services:)
    make_request(
      :patch,
      "clients/#{client_id}/additional_services",
      params: additional_services
    )
  end

  private

  API_CONTENT_TYPE = 'application/json'.freeze

  attr_reader :base_url, :login, :password, :application_source

  def connection
    @connection ||= HTTP.persistent(base_url)
  end

  def loan_request_terms(&block)
    result = make_request(:get, "loan_requests/#{loan_request_token}", &block)
    return result if result.success?

    Result.new(success?: false, response: { errors: { base: [:cant_fetch_loan_request_terms] } })
  end

  def make_request(method, endpoint, params: {}, headers: {}, &block)
    headers = { 'Authorization': session_token }.merge(headers).compact
    response = connection.public_send(
      method,
      url_for(endpoint),
      json: params,
      headers: headers
    )
    handle_response(response, &block)
  rescue HTTP::Error => e
    handle_error(e)
  end

  def handle_response(response)
    if response.status.success?
      if block_given?
        yield response
      else
        response
      end
      Result.new(success?: true, response: parse(response))
    else
      handle_error(response)
    end
  end

  def handle_error(response_or_exception)
    response = response_or_exception if response_or_exception.respond_to?(:status)
    if response
      if response.status.unauthorized?
        raise Revo::LoansApi::InvalidAccessTokenError
      else
        Result.new(success?: false, response: parse_errors(response))
      end
    else
      raise Revo::LoansApi::UnexpectedResponseError, response_or_exception
    end
  end

  def parse(response)
    response.parse if response.body.present?
  rescue HTTP::Error
    response.to_s.presence
  end

  def parse_errors(response)
    if response.content_type.mime_type == API_CONTENT_TYPE
      parse(response)
    else
      { errors: { base: [:unexpected_response] } }
    end
  end

  def url_for(endpoint)
    [base_url, endpoint].join('/')
  end

  def loan_request_params(options)
    { loan_request: options }
  end
end
