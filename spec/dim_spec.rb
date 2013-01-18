require 'dim'
require 'rspec/given'

RSpec::Given.use_natural_assertions

class ConsoleAppender
end

class Logger
  attr_accessor :appender
end

class FauxDB
end

class RealDB
  attr_accessor :username, :password
  def initialize(username, password)
    @username, @password = username, password
  end
end

class App
  attr_accessor :logger, :db
  def initialize(logger=nil)
    @logger = logger
  end
end

describe Dim::Container do
  let(:container) { Dim::Container.new }

  context "when creating objects" do
    Given { container.register(:app) { App.new } }
    Then  { container.app.kind_of?(App) }
  end

  describe "returning the same object every time" do
    Given { container.register(:app) { App.new } }
    Given(:app) { container.app }
    Then { container.app == app }
  end

  context "when contructing dependent objects" do
    Given { container.register(:app) { |c| App.new(c.logger) } }
    Given { container.register(:logger) { Logger.new } }
    Given(:app) { container.app }
    Then { app.logger == container.logger }
  end

  context "when constructing dependent objects with setters" do
    Given {
      container.register(:app) { |c|
        App.new.tap { |obj|
          obj.db = c.database
        }
      }
    }
    Given { container.register(:database) { FauxDB.new } }
    Given(:app) { container.app }

    Then { app.db == container.database }
  end

  context "when constructing multiple dependent objects" do
    Given {
      container.register(:app) { |c|
        App.new(c.logger).tap { |obj|
          obj.db = c.database
        }
      }
    }
    Given { container.register(:logger) { Logger.new } }
    Given { container.register(:database) { FauxDB.new } }
    Given(:app) { container.app }
    Then { app.logger == container.logger }
    Then { app.db == container.database }
  end

  context "when constructing chains of dependencies" do
    Given { container.register(:app) { |c| App.new(c.logger) } }
    Given {
      container.register(:logger) { |c|
        Logger.new.tap { |obj|
          obj.appender = c.logger_appender
        }
      }
    }
    Given { container.register(:logger_appender) { ConsoleAppender.new } }
    Given { container.register(:database) { FauxDB.new } }
    Given(:logger) { container.app.logger }

    Then { logger.appender == container.logger_appender }
  end

  context "when constructing literals" do
    Given { container.register(:database) { |c| RealDB.new(c.username, c.userpassword) } }
    Given { container.register(:username) { "user_name_value" } }
    Given { container.register(:userpassword) { "password_value" } }
    Given(:db) { container.database }

    Then { db.username == "user_name_value" }
    Then { db.password == "password_value" }
  end

  describe "Errors" do
    context "with missing services" do
      When(:result) { container.undefined_service_name }
      Then { result == have_failed(Dim::MissingServiceError, /undefined_service_name/) }
    end

    context "with duplicate service names" do
      Given { container.register(:duplicate_name) { 0 } }
      When(:result) { container.register(:duplicate_name) { 0 } }
      Then { result == have_failed(Dim::DuplicateServiceError, /duplicate_name/) }
    end
  end

  describe "Parent/Child Container Interaction" do
    Given(:parent) { container }
    Given(:child) { Dim::Container.new(parent) }

    Given { parent.register(:cell) { :parent_cell } }
    Given { parent.register(:gene) { :parent_gene } }
    Given { child.register(:gene) { :child_gene } }

    context "when reusing a service from the parent" do
      Then { child.cell == :parent_cell }
    end

    context "when overiding a service from the parent" do
      Then { child.gene == :child_gene }
    end

    context "when wrapping a service from a parent" do
      Given { child.register(:cell) { |c| [c.parent.cell] } }
      Then { child.cell == [:parent_cell] }
    end

    context "when overriding an indirect dependency" do
      Given { parent.register(:wrapped_cell) { |c| [c.cell] } }
      Given { child.register(:cell) { :child_cell } }
      Then { child.wrapped_cell == [:child_cell] }
    end

    context "when the parent / child service conflicts from parent's view" do
      Then { parent.gene == :parent_gene }
    end

    context "when child / child service name conflicts from the child's view" do
      Given(:other_child) { Dim::Container.new(parent) }
      Given { other_child.register(:gene) { :other_child_gene } }

      Then { child.gene == :child_gene }
      Then { other_child.gene == :other_child_gene }
    end
  end

end
