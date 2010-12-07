require 'dim'
require 'rspec/given'

class ConsoleAppender
end

class Logger
  attr_accessor :appender
end

class MockDB
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

  Scenario "creating objects" do
    Given { container.register(:app) { App.new } }
    Then  { container.app.should be_a(App) }
  end

  Scenario "returning the same object every time" do
    Given { container.register(:app) { App.new } }
    Given(:app)  { container.app }
    Then { container.app.should be(app) }
  end

  Scenario "contructing dependent objects" do
    Given { container.register(:app) { |c| App.new(c.logger) } }
    Given { container.register(:logger) { Logger.new } }
    Given(:app) { container.app }
    Then { app.logger.should be(container.logger) }
  end

  Scenario "constructing dependent objects with setters" do
    Given {
      container.register(:app) { |c|
        App.new.tap { |obj|
          obj.db = c.database
        }
      }
    }
    Given { container.register(:database) { MockDB.new } }
    Given(:app) { container.app }

    Then { app.db.should be(container.database) }
  end

  Scenario "constructing multiple dependent objects" do
    Given {
      container.register(:app) { |c|
        App.new(c.logger).tap { |obj|
          obj.db = c.database
        }
      }
    }
    Given { container.register(:logger) { Logger.new } }
    Given { container.register(:database) { MockDB.new } }
    Given(:app) { container.app }
    Then { app.logger.should be(container.logger) }
    Then { app.db.should be(container.database) }
  end

  Scenario "constructing chains of dependencies" do
    Given { container.register(:app) { |c| App.new(c.logger) } }
    Given {
      container.register(:logger) { |c|
        Logger.new.tap { |obj|
          obj.appender = c.logger_appender
        }
      }
    }
    Given { container.register(:logger_appender) { ConsoleAppender.new } }
    Given { container.register(:database) { MockDB.new } }
    Given(:logger) { container.app.logger }

    Then { logger.appender.should be(container.logger_appender) }
  end

  Scenario "constructing literals" do
    Given { container.register(:database) { |c| RealDB.new(c.username, c.userpassword) } }
    Given { container.register(:username) { "user_name_value" } }
    Given { container.register(:userpassword) { "password_value" } }
    Given(:db) { container.database }

    Then { db.username.should == "user_name_value" }
    Then { db.password.should == "password_value" }
  end

  describe "Errors" do
    Scenario "missing services" do
      Then {
        lambda {
          container.undefined_service_name
        }.should raise_error(Dim::MissingServiceError, /undefined_service_name/)
      }
    end

    Scenario "duplicate service names" do
      Given { container.register(:duplicate_name) { 0 } }
      Then {
        lambda {
          container.register(:duplicate_name) { 0 }
        }.should raise_error(Dim::DuplicateServiceError, /duplicate_name/)
      }
    end
  end

  describe "Parent/Child Container Interaction" do
    Given(:parent) { container }
    Given(:child) { Dim::Container.new(parent) }

    Given { parent.register(:cell) { :parent_cell } }
    Given { parent.register(:gene) { :parent_gene } }
    Given { child.register(:gene) { :child_gene } }

    Scenario "reusing a service from the parent" do
      Then { child.cell.should == :parent_cell }
    end

    Scenario "overiding a service from the parent" do
      Then "the child service overrides the parent" do
        child.gene.should == :child_gene
      end
    end

    Scenario "wrapping a service from a parent" do
      Given { child.register(:cell) { |c| [c.parent.cell] } }
      Then { child.cell.should == [:parent_cell] }
    end

    Scenario "overriding an indirect dependency" do
      Given { parent.register(:wrapped_cell) { |c| [c.cell] } }
      Given { child.register(:cell) { :child_cell } }
      Then { child.wrapped_cell.should == [:child_cell] }
    end

    Scenario "parent / child service conflicts from parents view" do
      Then { parent.gene.should == :parent_gene }
    end

    Scenario "child / child service name conflicts" do
      Given(:other_child) { Dim::Container.new(parent) }
      Given { other_child.register(:gene) { :other_child_gene } }

      Then { child.gene.should == :child_gene }
      Then { other_child.gene.should == :other_child_gene }
    end
  end

end
