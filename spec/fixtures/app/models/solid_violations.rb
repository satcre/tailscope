# frozen_string_literal: true

# This file contains various SOLID principle violations for testing

class SolidViolations
  # Complex conditional - multiple AND/OR operators
  def complex_condition(user, role, status)
    if user.active? && user.verified? && (role == "admin" || role == "moderator") && status != "banned"
      "allowed"
    end
  end

  # Deep nesting - 4+ levels
  def deeply_nested(data)
    if data
      if data[:user]
        if data[:user][:profile]
          if data[:user][:profile][:settings]
            data[:user][:profile][:settings][:theme]
          end
        end
      end
    end
  end

  # Boolean parameter (flag argument)
  def process(data, force = false)
    if force
      data.force_process
    else
      data.process
    end
  end

  # Large parameter list
  def create_user(name, email, age, phone, address, city, state, country)
    User.create(
      name: name,
      email: email,
      age: age,
      phone: phone,
      address: address,
      city: city,
      state: state,
      country: country
    )
  end

  # Primitive obsession - large hash
  def build_config
    { :timeout => 30, :retries => 3, :host => "localhost", :port => 8080, :protocol => "http", :debug => false }
  end

  # Primitive obsession - email validation
  def valid_email?(email)
    email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
  end

  # Explanatory comment - explaining "what" not "why"
  def calculate_total(items)
    # Initialize total to 0
    total = 0
    # Loop through each item
    items.each do |item|
      # Add item price to total
      total += item.price
    end
    total
  end
end

# God Object - many dependencies
class GodObject
  attr_reader :database, :cache, :logger, :mailer, :notifier, :queue, :storage, :metrics

  def initialize
    @database = Database.new
    @cache = Cache.new
    @logger = Logger.new
    @mailer = Mailer.new
    @notifier = Notifier.new
    @queue = Queue.new
    @storage = Storage.new
    @metrics = Metrics.new
  end

  def process
    database.query
    cache.get
    logger.info
    mailer.send
    notifier.notify
    queue.push
    storage.save
    metrics.track
  end
end

# Feature Envy - method uses more external than internal data
class FeatureEnvyExample
  def calculate_discount(order)
    subtotal = order.items.sum(&:price)
    discount_rate = order.customer.discount_rate
    max_discount = order.customer.max_discount
    applied_discount = subtotal * discount_rate
    [applied_discount, max_discount].min
  end
end

# Law of Demeter violation - 4+ method chains
class DemeterViolation
  def get_user_city
    user.profile.address.city.name.upcase
  end
end
