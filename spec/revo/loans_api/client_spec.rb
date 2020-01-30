RSpec.describe Revo::LoansApi::Client do
  describe 'session creation' do
    it 'returns a session token' do
      config = {
        login: 'some-agent',
        password: 'p@$$w0rd',
        base_url: 'https://revoup.ru/api/loans/v1'
      }
      client = described_class.new(config)

      VCR.use_cassette('session/success') do
        client.create_session
      end

      expect(client.session_token).to eq('some-token')
    end

    context 'when login/password are invalid' do
      it 'returns a list of errors' do
        config = {
          login: 'some-agent',
          password: 'p@$$w0rd',
          base_url: 'https://revoup.ru/api/loans/v1'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('session/invalid_credentials') do
          client.create_session
        end

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
          base_url: 'https://revoup.ru/api/loans/v1'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('session/server_error') do
          client.create_session
        end

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { base: [:unexpected_response] } }
        )
      end
    end

    context 'when server does not respond' do
      it 'raises `Revo::LoansApi::UnexpectedResponseError`' do
        config = {
          login: 'some-agent',
          password: 'p@$$w0rd',
          base_url: 'https://revoup.ru/api/loans/v1'
        }
        stub_request(:post, 'https://revoup.ru/api/loans/v1/sessions').to_timeout
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
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-session-token'
      }
      client = described_class.new(config)

      loan_request_token = VCR.use_cassette('loan_request/creation/success') do
        client.create_loan_request(
          amount: 3_000,
          mobile_phone: '78881234567',
          store_id: 309
        )
      end

      expect(loan_request_token).to have_attributes(
        success?: true,
        response: {
          token: 'some-lr-token',
          insurance_available: true,
          terms: [
            {
              term: 3,
              term_id: 50,
              monthly_payment: 1073.0,
              total_of_payments: 3219.0,
              sum_with_discount: 3000.0,
              total_overpayment: 219.0,
              sms_info: 79.0,
              product_code: '03',
              min_amount: 1000.0,
              max_amount: 0.0,
              schedule: [
                {
                  date: '26-11-2018',
                  amount: 1073.0
                },
                {
                  date: '26-12-2018',
                  amount: 1073.0
                },
                {
                  date: '27-01-2019',
                  amount: 1073.0
                }
              ]
            }
          ]
        }
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('loan_request/creation/invalid') do
          client.create_loan_request(
            amount: 3_000,
            mobile_phone: '78881234567',
            store_id: 12_345
          )
        end

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { store_id: ['не может быть пустым'] } }
        )
      end
    end

    context 'when `Authorization` header is invalid' do
      it 'raises `Revo::LoansApi::InvalidAccessTokenError`' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'fake'
        }
        client = described_class.new(config)

        expect {
          VCR.use_cassette('loan_request/creation/invalid_session_token') do
            client.create_loan_request(
              amount: 3_000,
              mobile_phone: '78881234567',
              store_id: 123
            )
          end
        }.to raise_error(Revo::LoansApi::InvalidAccessTokenError)
      end
    end
  end

  describe 'update loan request' do
    let(:token) { '3440d32b95406a78340fb9bd146f4cf2ef702ea3' }

    it 'returns success response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }

      client = described_class.new(config)

      loan_request_response = VCR.use_cassette('loan_request/update/success') do
        client.update_loan_request(
          token: 'some-lr-token',
          options: { amount: 3_000 }
        )
      end

      expect(loan_request_response).to have_attributes(
        success?: true,
        response: {
          terms: [
            {
              term: 3,
              term_id: 50,
              monthly_payment: 1073.0,
              total_of_payments: 3219.0,
              sum_with_discount: 3000.0,
              total_overpayment: 219.0,
              sms_info: 79.0,
              product_code: '03',
              min_amount: 1000.0,
              max_amount: 0.0,
              schedule: [
                {
                  date: '26-11-2018',
                  amount: 1073.0
                },
                {
                  date: '26-12-2018',
                  amount: 1073.0
                },
                {
                  date: '27-01-2019',
                  amount: 1073.0
                }
              ]
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
        stub_request(:put, "https://backend.qa.revoup.ru/api/loans/v1/loan_requests/#{token}").to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: { amount: ['не может быть пустым'] }
          }.to_json,
          status: 422
        )
        client = described_class.new(config)

        result = client.update_loan_request(token: token, options: { amount: 3_000 })

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { amount: ['не может быть пустым'] } }
        )
      end
    end

    context 'when `Authorization` header is invalid' do
      it 'raises `Revo::LoansApi::InvalidAccessTokenError`' do
        config = {
          base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }
        stub_request(:put, "https://backend.qa.revoup.ru/api/loans/v1/loan_requests/#{token}").to_return(
          headers: { 'Content-Type': 'text/html' },
          body: '',
          status: 401
        )
        client = described_class.new(config)

        expect {
          client.update_loan_request(token: token, options: { amount: 3_000 })
        }.to raise_error(Revo::LoansApi::InvalidAccessTokenError)
      end
    end
  end

  describe 'loan info fetching' do
    context 'when success response' do

      it 'returns loan info' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-token'
        }

        client = described_class.new(config)

        loan_info_response = VCR.use_cassette('loan_request/loan_info/success') do
          client.get_loan_request_info(
            token: 'some-lr-token',
            amount: 3_000
          )
        end

        expect(loan_info_response).to eq(
          [
            {
              term: 3,
              term_id: 50,
              monthly_payment: 1073.0,
              total_of_payments: 3219.0,
              sum_with_discount: 3000.0,
              total_overpayment: 219.0,
              sms_info: 79.0,
              product_code: '03',
              min_amount: 1000.0,
              max_amount: 0.0,
              schedule: [
                {
                  date: '26-11-2018',
                  amount: 1073.0
                },
                {
                  date: '26-12-2018',
                  amount: 1073.0
                },
                {
                  date: '27-01-2019',
                  amount: 1073.0
                }
              ]
            }
          ]
        )
      end
    end

    context 'when something is invalid' do
      it 'returns empty array' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        loan_info_response = VCR.use_cassette('loan_request/loan_info/invalid') do
          client.get_loan_request_info(
            token: 'some-lr-token',
            amount: 3_000
          )
        end

        expect(loan_info_response).to eq([])
      end
    end

    context 'when `Authorization` header is invalid' do
      it 'raises `Revo::LoansApi::InvalidAccessTokenError`' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'fake'
        }

        client = described_class.new(config)

        expect {
          VCR.use_cassette('loan_request/loan_info/invalid_session_token') do
            client.get_loan_request_info(
              token: 'some-lr-token',
              amount: 3_000
            )
          end
        }.to raise_error(Revo::LoansApi::InvalidAccessTokenError)
      end
    end
  end

  describe 'document fetching' do
    it 'returns the raw document in a given format' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-session-token'
      }
      client = described_class.new(config)

      document = VCR.use_cassette('document/success') do
        client.document(type: :offer, format: :pdf, token: 'some-lr-token')
      end

      expect(document).to have_attributes(
        success?: true,
        response: 'PDF%1.6-some-content'
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('document/invalid') do
          client.document(type: :offer, format: :pdf, token:'some-lr-token')
        end

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
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-session-token'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client_confirmation/success') do
        client.send_loan_confirmation_message(token: 'some-lr-token')
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('client_confirmation/invalid') do
          client.send_loan_confirmation_message(token: 'some-lr-token')
        end

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
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-session-token'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('loan_request/confirmation/success') do
        client.complete_loan_request(token: 'some-lr-token', code: '1111')
      end

      expect(result).to have_attributes(
        success?: true,
        response: {
          client: {
            first_name: 'Владилен',
            middle_name: 'Гарриевич',
            last_name: 'Пупкин',
            credit_limit: '6000.0',
            decision: 'approved',
            decision_code: 210,
            decision_message: 'Покупка на сумму 3000.0 ₽ успешно совершена!'
          }
        }
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('loan_request/confirmation/invalid') do
          client.complete_loan_request(token: 'some-lr-token', code: 'invalid')
        end

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { code: ['неправильный код'] } }
        )
      end
    end
  end

  describe 'loan creation' do
    it 'returns `true`' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-session-token'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('loan/creation/success') do
        client.create_loan(token: 'some-lr-token', term_id: 51)
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('loan/creation/invalid') do
          client.create_loan(token: 'some-lr-token', term_id: 51)
        end

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
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'some-session-token'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('loan/finalization/success') do
        client.finalize_loan(token: 'some-lr-token', code: '1111', sms_info: '1')
      end

      expect(result).to have_attributes(
        success?: true,
        response: {
          offer_id: '244244102',
          loan_application: {
            barcodes: {
              image: a_string_including('data:image/svg+xml;base64,'),
              text: '1ZZ0600023030002442441027'
            }
          }
        }
      )
    end

    context 'when something is invalid' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'some-session-token'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('loan/finalization/invalid') do
          client.finalize_loan(token: 'some-lr-token', code: nil)
        end

        expect(result).to have_attributes(
          success?: false,
          response: { errors: { confirmation_code: ['неправильный код'] } }
        )
      end
    end
  end

  context 'orders fetching' do
    let(:config) do
      {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
    end

    it 'returns list of orders' do
      stub_request(:get, 'https://backend.qa.revoup.ru/api/loans/v1/orders').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: {
          orders: [
            {
              id: '1525182',
              client_name: 'Иванов Иван Иванович',
              mobile_phone: '8882200001',
              barcode: '10009302315006587574891'
            },
            {
              id: '1525183',
              client_name: 'Петров Петр Петрович',
              mobile_phone: '8882200002',
              barcode: '10009302315006587574892'
            }
          ]
        }.to_json
      )

      client = described_class.new(config)

      result = client.orders(store_id: 1)

      expect(result).to have_attributes(
        success?: true,
        response: {
          orders: [
            {
              id: '1525182',
              client_name: 'Иванов Иван Иванович',
              mobile_phone: '8882200001',
              barcode: '10009302315006587574891'
            },
            {
              id: '1525183',
              client_name: 'Петров Петр Петрович',
              mobile_phone: '8882200002',
              barcode: '10009302315006587574892'
            }
          ]
        }
      )
    end

    context 'when filter by mobile_phone is present' do
      it 'returns list of selected orders' do
        stub_request(:get, 'https://backend.qa.revoup.ru/api/loans/v1/orders').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            orders: [
              {
                id: '1525182',
                client_name: 'Иванов Иван Иванович',
                mobile_phone: '8882200001',
                barcode: '10009302315006587574891'
              }
            ]
          }.to_json
        )

        client = described_class.new(config)

        result = client.orders(store_id: 1, filters: { mobile_phone: '8882200001' })

        expect(result).to have_attributes(
          success?: true,
          response: {
            orders: [
              {
                id: '1525182',
                client_name: 'Иванов Иван Иванович',
                mobile_phone: '8882200001',
                barcode: '10009302315006587574891'
              }
            ]
          }
        )
      end
    end
  end

  context 'sending return confirmation code' do
    let(:order_id) { '1525182' }

    it 'returns success response' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }

      stub_request(:post, "https://backend.qa.revoup.ru/api/loans/v1/orders/#{order_id}/send_return_confirmation_code").to_return(
        headers: { 'Content-Type': 'application/json' },
        body: ''
      )

      client = described_class.new(config)

      result = client.send_return_confirmation_code(order_id: order_id)

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end
  end

  context 'create return' do
    let(:order_id) { '1525182' }
    let(:confirmation_code) { '1111' }
    let(:amount) { 3_000 }
    let(:store_id) { 1 }
    let(:config) do
      {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }
    end

    it 'returns success response with valid data' do
      stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/returns').to_return(
        headers: { 'Content-Type': 'application/json' },
        body: {
          return: {
            id: '234',
            barcode: '2ZZ011235616399006082053267'
          }
        }.to_json
      )

      client = described_class.new(config)

      result = client.create_return(
        order_id: order_id,
        code: confirmation_code,
        amount: amount,
        store_id: store_id
      )

      expect(result).to have_attributes(
        success?: true,
        response: {
          return: {
            id: '234',
            barcode: '2ZZ011235616399006082053267'
          }
        }
      )
    end

    context 'when data is invalid' do
      let(:amount) { nil }
      let(:store_id) { 'fake' }

      it 'returns unprocessible entity response with valid hash' do
        stub_request(:post, 'https://backend.qa.revoup.ru/api/loans/v1/returns').to_return(
          headers: { 'Content-Type': 'application/json' },
          body: {
            errors: {
              amount: ['не может быть пустым'],
              store_id: ['не найден']
            }
          }.to_json,
          status: 422
        )

        client = described_class.new(config)

        result = client.create_return(
          order_id: order_id,
          code: confirmation_code,
          amount: amount,
          store_id: store_id
        )

        expect(result).to have_attributes(
          success?: false,
          response: {
            errors: {
              amount: ['не может быть пустым'],
              store_id: ['не найден']
            }
          }
        )
      end
    end
  end

  context 'return confirmation' do
    let(:return_id) { '234' }

    it 'returns success response' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }

      stub_request(:post, "https://backend.qa.revoup.ru/api/loans/v1/returns/#{return_id}/confirm").to_return(
        headers: { 'Content-Type': 'application/json' },
        body: ''
      )

      client = described_class.new(config)

      result = client.confirm_return(return_id: return_id)

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end
  end

  context 'return cancelation' do
    let(:return_id) { '234' }

    it 'returns success response' do
      config = {
        base_url: 'https://backend.qa.revoup.ru/api/loans/v1',
        session_token: 'some-token'
      }

      stub_request(:post, "https://backend.qa.revoup.ru/api/loans/v1/returns/#{return_id}/cancel").to_return(
        headers: { 'Content-Type': 'application/json' },
        body: ''
      )

      client = described_class.new(config)

      result = client.cancel_return(return_id: return_id)

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end
  end

  describe 'start self registraion' do
    it 'returns success response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/self_registration/success') do
        client.start_self_registration(
          token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3',
          mobile_phone: '78882223344'
        )
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    context 'when mobile_phone is blank' do
      it 'returns a list of errors' do
        config = {
          base_url: 'https://revoup.ru/api/loans/v1',
          session_token: 'f90f00aed176c1661f56'
        }
        client = described_class.new(config)

        result = VCR.use_cassette('client/self_registration/invalid') do
          client.start_self_registration(
            token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3',
            mobile_phone: ''
          )
        end

        expect(result).to have_attributes(
          success?: false,
          response: {
            errors: {
              mobile_phone: ['не может быть пустым']
            }
          }
        )
      end
    end
  end

  describe 'check client code' do
    it 'return success response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/check_code/success') do
        client.check_client_code(
          token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3',
          code: '1111'
        )
      end

      expect(result).to have_attributes(
        success?: true,
        response: {
          code: {
            valid: true
          }
        }
      )
    end
  end

  describe 'client creation' do
    it 'returns client information' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      client_params = {
        mobile_phone: '8882223344',
        first_name: 'Иван',
        middle_name: 'Иванович',
        last_name: 'Иванов',
        birth_date: '01-01-1990',
        email: 'user23423423423@example.com',
        area: 'Москва',
        settlement: 'Москва',
        street: 'Новая',
        house: '123',
        building: '123',
        apartment: '123',
        postal_code: '12345',
        black_mark: false,
        agrees_bki: '1',
        agrees_terms: '1',
        confirmation_code: '1111',
        password: 's3cure p4ssw0rd!',
        password_confirmation: 's3cure p4ssw0rd!',
        id_documents: {
          russian_passport: {
            number: '123456',
            series: '2204'
          }
        }
      }

      result = VCR.use_cassette('client/success') do
        client.create_client(
          token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3',
          client_params: client_params
        )
      end

      expect(result).to have_attributes(
        success?: true,
        response: {
          client: {
            email: 'user23423423423@example.com',
            birth_date: '01-01-1990',
            first_name: 'Иван',
            middle_name: 'Иванович',
            last_name: 'Ивановтест',
            area: 'Москва',
            settlement: 'Москва',
            street: 'Новая',
            house: '123',
            building: '123',
            apartment: '123',
            postal_code: '12345',
            credit_limit: nil,
            missing_documents: ['name', 'client_with_passport', 'living_addr'],
            id_documents: {
              russian_passport: {
                number: '123456',
                series: '2204',
                expiry_date: nil
              }
            },
            decision: 'approved',
            credit_decision: 'approved',
            decision_code: 210,
            decision_message: 'Покупка на сумму 5000.0 ₽ успешно совершена!'
          }
        }
      )
    end
  end

  describe 'update client' do
    it 'returns success response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/updater/success') do
        client.update_client(
          id: '18141',
          client_params: {
            mobile_phone: '8882223344',
            email: 'userfakeemail@example.com'
          }
        )
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    it 'returns unprocessible response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/updater/failure') do
        client.update_client(
          id: '18141',
          client_params: {
            mobile_phone: '8882223344',
            email: 'userfakeemail@example.com'
          }
        )
      end

      expect(result).to have_attributes(
        success?: false,
        response: {
          errors: {
            email: ['уже существует']
          }
        }
      )
    end
  end

  describe 'create virtual card' do
    it 'returns success response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('virtual_card/success') do
        client.create_virtual_card(token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3', term_id: 1)
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    it 'returns unprocessible response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('virtual_card/failure') do
        client.create_virtual_card(token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3', term_id: 1)
      end

      expect(result).to have_attributes(
        success?: false,
        response: {
          errors: {
            loan_application: ['не может быть пустым']
          }
        }
      )
    end
  end

  describe 'create card loan' do
    it 'returns success response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('card_loan/success') do
        client.create_card_loan(token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3', term_id: 123)
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    it 'returns unprocessible response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('card_loan/failure') do
        client.create_card_loan(token: '3440d32b95406a78340fb9bd146f4cf2ef702ea3', term_id: 123)
      end

      expect(result).to have_attributes(
        success?: false,
        response: {
          errors: {
            amount: ['может иметь значение меньшее или равное 300'],
            term_id: ['не найден']
          }
        }
      )
    end
  end

  describe '#send_billing_shift_confirmation_code' do
    it 'returns success response' do
      config = {
        base_url: 'https://backend.st.revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/billing_shift/send_code/success') do
        client.send_billing_shift_confirmation_code(mobile_phone: '78881234567')
      end

      expect(result).to have_attributes(
        success?: true,
        response: nil
      )
    end

    it 'returns unprocessible response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/billing_shift/send_code/failure') do
        client.send_billing_shift_confirmation_code(mobile_phone: '78881234567')
      end

      expect(result).to have_attributes(
        success?: false,
        response: {
          errors: {
            base: [:unexpected_response]
          }
        }
      )
    end
  end

  describe 'show billing shift info' do
    it 'returns success response' do
      config = {
        base_url: 'https://backend.st.revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/billing_shift/info/success') do
        client.billing_shift_info(mobile_phone: '78881234567')
      end

      expect(result).to have_attributes(
        success?: true,
        response: [
          { billing_chain: 4, date: '2020-02-26' },
          { billing_chain: 1, date: '2020-03-02' },
          { billing_chain: 2, date: '2020-03-10' }
        ]
      )
    end

    it 'returns unprocessible response' do
      config = {
        base_url: 'https://revoup.ru/api/loans/v1',
        session_token: 'f90f00aed176c1661f56'
      }
      client = described_class.new(config)

      result = VCR.use_cassette('client/billing_shift/info/failure') do
        client.billing_shift_info(mobile_phone: '78881234567')
      end

      expect(result).to have_attributes(
        success?: false,
        response: {
          errors: {
            base: [:unexpected_response]
          }
        }
      )
    end
  end
end
