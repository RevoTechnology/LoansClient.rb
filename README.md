# Revo::LoansApi

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'revo-loans_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install revo-loans_api

## Usage

### Instantiating a client

Besides providing `base_url`, you must either use your login & password or a sesion token when instantiating the client:

```ruby
client = Revo::LoansApi::Client.new(base_url: '...', login: '70001112233', password: '1234')
# or session_token:
client = Revo::LoansApi::Client.new(base_url: '...', session_token: 'abcdef')
```

### Authenticating

```ruby
result = client.create_session

# Success:
result.success? # => true
# the token will automatically be used by the client (it's in `client.session_token`)

# Failure:
result.success? # => false
result.response # => `{ errors: { manager: ['list of errors here'] } }`
```

### Creating a loan request

```ruby
result = client.create_loan_request(
  amount: 3_000,
  mobile_phone: '78881234567',
  store_id: 309
)

# Success:
result.success? # => true
result.response # =>
# token: 'some-lr-token', # you'll be using this value on later steps
# terms: [
#   {
#     term: 3,
#     term_id: 50,
#     monthly_payment: 1073.0,
#     total_of_payments: 3219.0,
#     sum_with_discount: 3000.0,
#     total_overpayment: 219.0,
#     sms_info: 79.0,
#     product_code: '03',
#     min_amount: 1000.0,
#     max_amount: 0.0,
#     schedule: [
#       {
#         date: '26-12-2018',
#         amount: 1073.0
#       },
#       {
#         date: '27-01-2019',
#         amount: 1073.0
#       }
#     ]
#   }
# ]

# Failure:
result.success? # => false
result.response # => `{ errors: { store_id: ['list of errors here'] } }`
```

### Updating a loan request

```ruby
result = client.update_loan_request(
  token: 'some-lr-token', # use the one you got when creating a loan request
  options: { amount: 3000 }
)

# Success:
result.success? # => true
result.response # => `{}`

# Failure:
result.success? # => false
result.response # => `{ errors: { amount: ['list of errors here'] } }`
```

### Documents

```ruby
result = client.document(
  token: 'some-lr-token', # use the one you got when creating a loan request
  type: :offer,
  format: :pdf
)

# Success:
result.success? # => true
result.response # => (the raw data)

# Failure:
result.success? # => false
result.response # => `{ errors: { client: ['list of errors here'] } }`
```

### Sending a loan confirmation text

```ruby
result = client.send_loan_confirmation_message(
  token: 'some-lr-token' # use the one you got when creating a loan request
)

# Success:
result.success? # => true
result.response # => `nil`

# Failure:
result.success? # => false
result.response # => `{ errors: { mobile_phone: ['list of errors here'] } }`
```

### Completing a loan request

```ruby
result = client.complete_loan_request(
  token: 'some-lr-token', # use the one you got when creating a loan request
  code: '1234' # use the code from the text you received
)

# Success:
result.success? # => true
result.response # =>
# client: {
#   first_name: 'Владилен',
#   middle_name: 'Гарриевич',
#   last_name: 'Пупкин',
#   credit_limit: '6000.0',
#   decision: 'approved',
#   decision_code: 210,
#   decision_message: 'Покупка на сумму 3000.0 ₽ успешно совершена!'
# }

# Failure:
result.success? # => false
result.response # => `{ errors: { code: ['list of errors here'] } }`
```

### Creating a loan

```ruby
result = client.create_loan(
  token: 'some-lr-token', # use the one you got when creating a loan request
  term_id: 51 # pick one of those provided when creating a loan request
)

# Success:
result.success? # => true
result.response # => `nil`

# Failure:
result.success? # => false
result.response # => `{ errors: { base: ['list of errors here'] } }`
```

### Finalizing a loan

```ruby
result = client.finalize_loan(
  token: 'some-lr-token', # use the one you got when creating a loan request
  code: '1234' # use the code from the text you received (the same one)
)

# Success:
result.success? # => true
result.response # =>
# offer_id: '244244102',
# loan_application: {
#   barcodes: {
#     image: 'data:image/svg+xml;base64,...',
#     text: '1ZZ0600023030002442441027'
#   }
# }

# Failure:
result.success? # => false
result.response # => `{ errors: { confirmation_code: ['list of errors here'] } }`
```

### List orders

```ruby
result = client.orders(
  store_id: 1,
  filters: { mobile_phone: '8881112233' } # optional
)

# Success:
result.success? # => true
result.response # =>
# orders: [
#   {
#     id: '1525182',
#     client_name: 'Иванов Иван Иванович',
#     mobile_phone: '8882200001',
#     barcode: '10009302315006587574891'
#   }
# ]
```

### Send return confirmation code

```ruby
result = client.send_return_confirmation_code(
  order_id: 1
)

# Success:
result.success? # => true
result.response # => `nil`
```

### Creating a return

```ruby
result = client.create_return(
  order_id: 1,
  code: '1234',
  amount: 3000,
  store_id: 1
)

# Success:
result.success? # => true
result.response # =>
# return: {
#   id: '234',
#   barcode: '2ZZ011235616399006082053267'
# }

# Failure:
result.success? # => false
result.response # => `{ errors: { amount: ['error'], store_id: ['another error'] } }`
```

### Confirming a return

```ruby
result = client.confirm_return(
  return_id: 1
)

# Success:
result.success? # => true
result.response # => `nil`
```

### Cancelling a return

```ruby
result = client.cancel_return(
  return_id: 1
)

# Success:
result.success? # => true
result.response # => `nil`
```


### Start self registration


```ruby
result = client.start_self_registration(
  token: 'some-lr-token', # use the one you got when creating a loan request
  mobile_phone: '78881234567'
)

# Success:
result.success? # => true
result.response # => `nil`

# Failure:
result.success? # => false
result.response # => `{ errors: { mobile_phone: ['error'] } }`
```


### Check client confirmation code


```ruby
result = client.check_client_code(
  token: 'some-lr-token', # use the one you got when creating a loan request
  code: '1234'
)

# Success:
result.success? # => true
result.response # => `{ code: { valid: true } }`

# Failure:
result.success? # => true
result.response # => `{ code: { valid: false } }`
```


### Update client data


```ruby
result = client.create_client(
  token: 'some-lr-token', # use the one you got when creating a loan request
  client_params: {
    mobile_phone: '8881234567',
    first_name: 'Иван',
    middle_name: 'Иванович',
    last_name: 'Иванов',
    birth_date: '01-01-1990',
    email: 'user@example.com',
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
  },
  provider_data: {}
)

# Success:
result.success? # => true
result.response # =>
# client: {
#   email: 'user@example.com',
#   birth_date: '01-01-1990',
#   first_name: 'Иван',
#   middle_name: 'Иванович',
#   last_name: 'Ивановтест',
#   area: 'Москва',
#   settlement: 'Москва',
#   street: 'Новая',
#   house: '123',
#   building: '123',
#   apartment: '123',
#   postal_code: '12345',
#   credit_limit: nil,
#   missing_documents: ['name', 'client_with_passport', 'living_addr'],
#   id_documents: {
#     russian_passport: {
#       number: '123456',
#       series: '2204',
#       expiry_date: nil
#     }
#   },
#   decision: 'approved',
#   credit_decision: 'approved',
#   decision_code: 210,
#   decision_message: 'Покупка на сумму 5000.0 ₽ успешно совершена!'
# }

# Failure 422:
result.success? # => false
result.response # => `{ errors: { mobile_phone: ['error'], id_documents: { russian_passport: ['another error'] } }`

# Failure 452:
result.success? # => false
result.response # =>
# client: {
#   email: 'user@example.com',
#   birth_date: '01-01-1990',
#   first_name: 'Иван',
#   middle_name: 'Иванович',
#   last_name: 'Ивановтест',
#   area: 'Москва',
#   settlement: 'Москва',
#   street: 'Новая',
#   house: '123',
#   building: '123',
#   apartment: '123',
#   postal_code: '12345',
#   credit_limit: nil,
#   missing_documents: ['name', 'client_with_passport', 'living_addr'],
#   id_documents: {
#     russian_passport: {
#       number: '123456',
#       series: '2204',
#       expiry_date: nil
#     }
#   },
#   decision: 'declined',
#   credit_decision: 'declined',
#   decision_code: 610,
#   decision_message: 'К сожалению, Ваша заявка отклонена'
# }
```


### Possible Exceptions

In case of generic HTTP errors (i.e. server is not reachable or network is down), `Revo::LoansApi::UnexpectedResponseError` will be raised.

If the provided session token is invalid, you'll get `Revo::LoansApi::InvalidAccessTokenError`.
In this case, you have to get a new one using your login and password by calling `#create_session`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/RevoTechnology/LoansClient.rb.
