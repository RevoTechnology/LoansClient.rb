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

  def initialize(base_url:, login: nil, password: nil, session_token: nil)
    @base_url = base_url
    @login = login
    @password = password
    @session_token = session_token
  end

  def create_session
    make_request(
      :post, 'sessions',
      user: { login: login, password: password }
    ).tap do |result|
      @session_token = result.response.dig(:user, :authentication_token) if result&.success?
    end
  end

  def create_loan_request(amount:, mobile_phone:, store_id:)
    loan_request_params = {
      loan_request: {
        mobile_phone: mobile_phone,
        amount: amount,
        store_id: store_id
      }
    }
    response = make_request(:post, 'loan_requests', loan_request_params)
    return response unless response.success?
    @loan_request_token = response.response.dig(:loan_request, :token)
    Result.new(
      success?: true,
      response: {
        token: loan_request_token,
        terms: loan_request_terms.response[:loan_request]
      }
    )
  end

  # prerequisite: a client with the LR's phone number should already exist
  def document(token:, type:, format: 'html')
    make_request(:get, "loan_requests/#{token}/documents/#{type}.#{format}")
  end

  def send_loan_confirmation_message(token:)
    make_request(:post, "loan_requests/#{token}/client/confirmation")
  end

  def complete_loan_request(token:, code:)
    make_request(:post, "loan_requests/#{token}/confirmation", code: code)
  end

  def create_loan(token:, term_id:)
    make_request(:post, "loan_requests/#{token}/loan", term_id: term_id)
  end

  def finalize_loan(token:, code:)
    make_request(:post, "loan_requests/#{token}/loan/finalization", loan: { agree_processing: '1', confirmation_code: code })
  end

  private

  attr_reader :connection, :base_url, :login, :password

  def connection
    @connection ||= HTTP.persistent(base_url)
  end

  def loan_request_terms(&block)
    make_request(:get, "loan_requests/#{loan_request_token}", &block)
  end

  def make_request(method, endpoint, params = {}, &block)
    headers = { Authorization: session_token }.compact
    response = connection.public_send(method, url_for(endpoint), json: params, headers: headers)
    handle_response(response, &block)
  rescue HTTP::Error => exception
    handle_error(exception)
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
        Result.new(success?: false, response: parse(response))
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

  def url_for(endpoint)
    [base_url, endpoint].join('/')
  end
end
