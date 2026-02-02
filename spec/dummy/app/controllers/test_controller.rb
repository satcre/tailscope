# frozen_string_literal: true

class TestController < ActionController::Base
  def index
    render plain: "OK"
  end

  def error_test
    raise "Test error"
  end
end
