RSpec.describe Revo::LoansApi::Client do
  describe 'session creation' do
    it 'returns a session token' do
      config = {
        login: 'some-agent',
        password: 'p@$$w0rd',
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1'
      }
      stubbed_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/sessions').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: {
          user: { authentication_token: 'some-token' }
        }.to_json
      )
      client = described_class.new(config)

      client.create_session

      expect(stubbed_request.with(
        body: {
          user: {
            login: 'some-agent',
            password: 'p@$$w0rd'
          }
        }
      )).to have_been_requested
      expect(client.session_token).to eq('some-token')
    end

    context 'when login/password are invalid' do
      it 'returns a list of errors' do
        config = {
          login: 'some-agent',
          password: 'p@$$w0rd',
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1'
        }
        stubbed_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/sessions').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { manager: ['неверный логин и/или пароль'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.create_session

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { manager: ['неверный логин и/или пароль'] } }
        )
      end
    end

    context 'when server fails with HTTP 500' do
      it 'raises `Revo::LoansApi::UnexpectedResponseError`' do
        config = {
          login: 'some-agent',
          password: 'p@$$w0rd',
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1'
        }
        stubbed_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/sessions').to_return(
          headers: { 'Content-Type': 'application/json' },
          status: 500
        )
        client = described_class.new(config)

        result = client.create_session

        expect(result).to have_attributes(
          success?: false,
          response: nil
        )
      end
    end

    context 'when server does not respond' do
      it 'raises `Revo::LoansApi::UnexpectedResponseError`' do
        config = {
          login: 'some-agent',
          password: 'p@$$w0rd',
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1'
        }
        stubbed_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/sessions').to_timeout
        client = described_class.new(config)

        expect {
          client.create_session
        }.to raise_error(Revo::LoansApi::UnexpectedResponseError)
      end
    end
  end

  describe 'loan request creation' do
    it 'returns a token along with terms' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
      stubbed_creation_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: {
          loan_request: { token: 'some-lr-token' }
        }.to_json
      )
      stubbed_details_request = stub_request(:get, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: {
          loan_request: [
            {
              max_amount: 0.0,
              min_amount: 0.0,
              monthly_payment: 500.0,
              product_code: 6,
              schedule: [
                {
                  amount: 500.0,
                  date: '16-04-2020'
                }
              ],
              sms_info: 79.0,
              sum_with_discount: 3000.0,
              term: 6,
              term_id: 117,
              total_of_payments: 3000.0,
              total_overpayment: 0.0
            }
          ]
        }.to_json
      )
      client = described_class.new(config)

      loan_request_token = client.create_loan_request(
        amount: 3_000,
        mobile_phone: '78881234567',
        store_id: 123
      )

      expect(stubbed_creation_request.with(
        body: {
          loan_request: {
            mobile_phone: '78881234567',
            amount: 3_000,
            store_id: 123
          }
        },
        headers: { Authorization: 'some-token' }
      )).to have_been_requested
      expect(stubbed_details_request.with(
        headers: { Authorization: 'some-token' }
      )).to have_been_requested
      expect(loan_request_token).to have_attributes(
        success?: true,
        response: {
          token: 'some-lr-token',
          terms: [
            {
              max_amount: 0.0,
              min_amount: 0.0,
              monthly_payment: 500.0,
              product_code: 6,
              schedule: [
                {
                  amount: 500.0,
                  date: '16-04-2020'
                }
              ],
              sms_info: 79.0,
              sum_with_discount: 3000.0,
              term: 6,
              term_id: 117,
              total_of_payments: 3000.0,
              total_overpayment: 0.0
            }
          ]
        }
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stubbed_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { store_id: ['не может быть пустым'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.create_loan_request(
          amount: 3_000,
          mobile_phone: '78881234567',
          store_id: 123
        )

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { store_id: ['не может быть пустым'] } }
        )
      end
    end

    context 'when `Authorization` header is invalid' do
      it 'raises `Revo::LoansApi::InvalidAccessTokenError`' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stubbed_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests').to_return(
          headers: { 'Content-Type': 'text/html' },
          body: '',
          status: 401
        )
        client = described_class.new(config)

        expect {
          client.create_loan_request(
            amount: 3_000,
            mobile_phone: '78881234567',
            store_id: 123
          )
        }.to raise_error(Revo::LoansApi::InvalidAccessTokenError)
      end
    end
  end

  describe 'document fetching' do
    it 'returns the raw document in a given format' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
      stubbed_document_request = stub_request(:get, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/documents/offer.pdf').to_return(
        headers: { 'Content-Type': 'application/pdf' },
        body: 'PDF%1.6-some-content'
      )
      client = described_class.new(config)

      document = client.document(type: :offer, format: :pdf, token: 'some-lr-token')

      expect(stubbed_document_request.with(
        headers: { Authorization: 'some-token' }
      )).to have_been_requested
      expect(document).to have_attributes(
        success?: true,
        response: 'PDF%1.6-some-content'
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stubbed_document_request = stub_request(:get, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/documents/offer.pdf').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { client: ['ещё не создан'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.document(type: :offer, format: :pdf, token: 'some-lr-token')

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { client: ['ещё не создан'] } }
        )
      end
    end
  end

  describe 'loan confirmation message sending' do
    it 'returns `true`' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
      stubbed_text_sending_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/client/confirmation').to_return(
        headers: { 'Content-Type': 'text/html' },
        body: ''
      )
      client = described_class.new(config)

      result = client.send_loan_confirmation_message(token: 'some-lr-token')

      expect(stubbed_text_sending_request.with(
        headers: { Authorization: 'some-token' }
      )).to have_been_requested
      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/client/confirmation').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { mobile_phone: ['не может быть пустым'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.send_loan_confirmation_message(token: 'some-lr-token')

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { mobile_phone: ['не может быть пустым'] } }
        )
      end
    end
  end

  describe 'loan request completion' do
    it 'returns a scored client' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
      stubbed_completion_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/confirmation').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: {
          client: {
            first_name: 'Владилен',
            middle_name: 'Гарриевич',
            last_name: 'Пупкин',
            credit_limit: '6000.0',
            decision: 'declined',
            decision_code: 710,
            decision_message: 'К сожалению, сегодня мы не можем одобрить Вашу заявку.'
          }
        }.to_json
      )
      client = described_class.new(config)

      result = client.complete_loan_request(token: 'some-lr-token', code: '1234')

      expect(stubbed_completion_request.with(
        headers: { Authorization: 'some-token' },
        body: { code: '1234' }
      )).to have_been_requested
      expect(result).to have_attributes(
        success?: true,
        response: {
          client: {
            first_name: 'Владилен',
            middle_name: 'Гарриевич',
            last_name: 'Пупкин',
            credit_limit: '6000.0',
            decision: 'declined',
            decision_code: 710,
            decision_message: 'К сожалению, сегодня мы не можем одобрить Вашу заявку.'
          }
        }
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/confirmation').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { client: ['не может быть пустым'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.complete_loan_request(token: 'some-lr-token', code: '1234')

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { client: ['не может быть пустым'] } }
        )
      end
    end
  end

  describe 'loan creation' do
    it 'returns `true`' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
      stubbed_completion_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/loan').to_return(
        headers: { 'Content-Type': 'text/html' },
        body: ''
      )
      client = described_class.new(config)

      result = client.create_loan(token: 'some-lr-token', term_id: 6)

      expect(stubbed_completion_request.with(
        headers: { Authorization: 'some-token' },
        body: { term_id: 6 }
      )).to have_been_requested
      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/loan').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { base: ['К сожалению, ваша заявка отклонена'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.create_loan(token: 'some-lr-token', term_id: 6)

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { base: ['К сожалению, ваша заявка отклонена'] } }
        )
      end
    end
  end

  describe 'loan finalization' do
    it 'returns a list of barcodes and the order ID' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
      stubbed_completion_request = stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/loan/finalization').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: <<~JSON
          {
            "offer_id": "871169296",
            "loan_application": {
              "barcodes": [
                {
                  "image": "data:image/svg+xml;base64,abc",
                  "text": "871169296"
                },
                {
                  "image": "data:image/svg+xml;base64,abc",
                  "text": "$MT REV  011 K"
                },
                {
                  "image": "data:image/svg+xml;base64,abc",
                  "text": "N%PUPKIN%VLADILEN%GARRIEVI4"
                },
                {
                  "image": "data:image/svg+xml;base64,abc",
                  "text": "E%0030000000000000291019"
                },
                {
                  "image": "data:image/svg+xml;base64,abc",
                  "text": "RS%40702810887880000949"
                }
              ]
            }
          }
        JSON
      )
      client = described_class.new(config)

      result = client.finalize_loan(token: 'some-lr-token', code: '1111')

      expect(stubbed_completion_request.with(
        headers: { Authorization: 'some-token' },
        body: { loan: { agree_processing: '1', confirmation_code: '1111' } }
      )).to have_been_requested
      expect(result).to have_attributes(
        success?: true,
        response: {
          offer_id: '871169296',
          loan_application: {
            barcodes: [
              {
                image: 'data:image/svg+xml;base64,abc',
                text: '871169296'
              },
              {
                image: 'data:image/svg+xml;base64,abc',
                text: '$MT REV  011 K'
              },
              {
                image: 'data:image/svg+xml;base64,abc',
                text: 'N%PUPKIN%VLADILEN%GARRIEVI4'
              },
              {
                image: 'data:image/svg+xml;base64,abc',
                text: 'E%0030000000000000291019'
              },
              {
                image: 'data:image/svg+xml;base64,abc',
                text: 'RS%40702810887880000949'
              }
            ]
          }
        }
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/loan_requests/some-lr-token/loan/finalization').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { agree_processing: ['не может быть пустым'], confirmation_code: ['неправильный код'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.finalize_loan(token: 'some-lr-token', code: nil)

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { agree_processing: ['не может быть пустым'], confirmation_code: ['неправильный код'] } }
        )
      end
    end
  end
end
