require 'revo/loans_api/version'
require 'revo/loans_api/client'

module Revo
  module LoansApi
    class Error < StandardError; end
    class UnprocessableEntityError < Error; end
    class UnexpectedResponseError < Error; end
    class InvalidAccessTokenError < Error; end
  end
end
