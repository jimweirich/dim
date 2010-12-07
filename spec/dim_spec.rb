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

describe DIM::Container do
  let(:container) { DIM::Container.new }

  context "can create objects" do
    Given { container.register(:app) { App.new } }
    Then  { container.app.should be_a(App) }
  end

  context "returns the same object every time" do
    Given { container.register(:app) { App.new } }
    Given(:app)  { container.app }
    Then { container.app.should be(app) }
  end

  context "contructs dependent objects" do
    Given { container.register(:app) { |c| App.new(c.logger) } }
    Given { container.register(:logger) { Logger.new } }
    Given(:app) { container.app }
    Then { app.logger.should be(container.logger) }
  end

  context "constructs dependent objects with setters" do
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

  context "constructs multiple dependent objects" do
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

  context "constructs chains of dependencies" do
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

  context "constructs literals" do
    Given { container.register(:database) { |c| RealDB.new(c.username, c.userpassword) } }
    Given { container.register(:username) { "jim" } }
    Given { container.register(:userpassword) { "secret" } }
    Given(:db) { container.database }

    Then { db.username.should == "jim" }
    Then { db.password.should == "secret" }
  end

  it "complains about missing services" do
    lambda {
      container.not_here
    }.should raise_error(DIM::MissingServiceError, /not_here/)
  end

  it "complains about duplicate service names" do
    container.register(:app) { 0 }
    lambda {
      container.register(:app) { 0 }
    }.should raise_error(DIM::DuplicateServiceError, /app/)
  end

  describe "Child Containers" do
    let(:child) { DIM::Container.new(container) }

    context "reuses a service from the parent" do
      Given { container.register(:gene) { :x } }
      Then { child.gene.should == :x }
    end

    context "can overide a servie from the parent" do
      Given { container.register(:gene) { :x } }
      Given { child.register(:gene) { :y } }
      Then { child.gene.should == :y }
    end

    context "can override an indirect dependency" do
      Given { container.register(:thing) { |c| c.real_thing } }
      Given { container.register(:real_thing) { "THING" } }
      Given { child.register(:real_thing) { "NEWTHING" } }
      Then { child.thing.should == "NEWTHING" }
    end

    context "the parent is uneffected by child registrations" do
      Given { container.register(:gene) { :x } }
      Given { child.register(:gene) { :y } }
      Then { container.gene.should == :x }
    end

    context "multiple children do not interer with each other" do
      Given(:a) { DIM::Container.new(container) }
      Given(:b) { DIM::Container.new(container) }

      Given { container.register(:gene) { :x } }
      Given { a.register(:gene) { :a } }
      Given { b.register(:gene) { :b } }

      Then { a.gene.should == :a }
      Then { b.gene.should == :b }
    end
  end

end
