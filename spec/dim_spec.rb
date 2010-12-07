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

  context "creating objects" do
    Given { container.register(:app) { App.new } }
    Then  { container.app.should be_a(App) }
  end

  context "returning the same object every time" do
    Given { container.register(:app) { App.new } }
    Given(:app)  { container.app }
    Then { container.app.should be(app) }
  end

  context "contructing dependent objects" do
    Given { container.register(:app) { |c| App.new(c.logger) } }
    Given { container.register(:logger) { Logger.new } }
    Given(:app) { container.app }
    Then { app.logger.should be(container.logger) }
  end

  context "constructing dependent objects with setters" do
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

  context "constructing multiple dependent objects" do
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

  context "constructing chains of dependencies" do
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

  context "constructing literals" do
    Given { container.register(:database) { |c| RealDB.new(c.username, c.userpassword) } }
    Given { container.register(:username) { "jim" } }
    Given { container.register(:userpassword) { "secret" } }
    Given(:db) { container.database }

    Then { db.username.should == "jim" }
    Then { db.password.should == "secret" }
  end

  context "missing services" do
    Then {
      lambda {
        container.not_here
      }.should raise_error(Dim::MissingServiceError, /not_here/)
    }
  end

  context "duplicate service names" do
    Given { container.register(:app) { 0 } }
    Then {
      lambda {
        container.register(:app) { 0 }
      }.should raise_error(Dim::DuplicateServiceError, /app/)
    }
  end

  describe "Child Containers" do
    Given(:child) { Dim::Container.new(container) }
    Given(:other_child) { Dim::Container.new(container) }

    Given { container.register(:cell) { :parent_cell } }
    Given { container.register(:gene) { :parent_gene } }
    Given { child.register(:gene) { :child_gene } }
    Given { other_child.register(:gene) { :other_child_gene } }

    context "reusing a service from the parent" do
      Then { child.cell.should == :parent_cell }
    end

    context "overiding a service from the parent" do
      Then { child.gene.should == :child_gene }
    end

    context "wrapping a service from a parent" do
      Given { child.register(:cell) { |c| [c.parent.cell] } }
      Then { child.cell.should == [:parent_cell] }
    end

    context "overriding an indirect dependency" do
      Given { container.register(:wrapped_cell) { |c| [c.cell] } }
      Given { child.register(:cell) { :child_cell } }
      Then { child.wrapped_cell.should == [:child_cell] }
    end

    context "parent / child service conflicts" do
      Then { container.gene.should == :parent_gene }
    end

    context "child / child service name conflicts" do
      Then { child.gene.should == :child_gene }
      Then { other_child.gene.should == :other_child_gene }
    end
  end

end
