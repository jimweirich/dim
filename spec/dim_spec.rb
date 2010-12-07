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
    let(:child) { Dim::Container.new(container) }

    context "reusing a service from the parent" do
      Given { container.register(:gene) { :x } }
      Then { child.gene.should == :x }
    end

    context "overiding a service from the parent" do
      Given { container.register(:gene) { :x } }
      Given { child.register(:gene) { :y } }
      Then { child.gene.should == :y }
    end

    context "wrapping a service from a parent" do
      Given { container.register(:gene) { :x } }
      Given { child.register(:gene) { |c| [c.parent.gene] } }
      Then { child.gene.should == [:x] }
    end

    context "overriding an indirect dependency" do
      Given { container.register(:thing) { |c| c.real_thing } }
      Given { container.register(:real_thing) { "THING" } }
      Given { child.register(:real_thing) { "NEWTHING" } }
      Then { child.thing.should == "NEWTHING" }
    end

    context "parent / child service conflicts" do
      Given { container.register(:gene) { :x } }
      Given { child.register(:gene) { :y } }
      Then { container.gene.should == :x }
    end

    context "child / child service name conflicts" do
      Given(:a) { Dim::Container.new(container) }
      Given(:b) { Dim::Container.new(container) }

      Given { container.register(:gene) { :x } }
      Given { a.register(:gene) { :a } }
      Given { b.register(:gene) { :b } }

      Then { a.gene.should == :a }
      Then { b.gene.should == :b }
    end
  end

end
