require 'dim'

# TODO: use tap
# TODO: use rspec-given

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

  it "can create objects" do
    container.register(:app) { App.new }
    container.app.should be_a(App)
  end

  it "returns the same object every time" do
    container.register(:app) { App.new }
    app = container.app
    container.app.should be(app)
  end

  it "contructs dependent objects" do
    container.register(:app) { |c| App.new(c.logger) }
    container.register(:logger) { Logger.new }
    app = container.app
    app.logger.should be(container.logger)
  end

  it "constructs dependent objects with setters" do
    container.register(:app) { |c|
      app = App.new
      app.db = c.database
      app
    }
    container.register(:database) { MockDB.new }
    app = container.app
    app.db.should be(container.database)
  end

  it "constructs multiple dependent objects" do
    container.register(:app) { |c|
      app = App.new(c.logger)
      app.db = c.database
      app
    }
    container.register(:logger) { Logger.new }
    container.register(:database) { MockDB.new }

    app = container.app
    app.logger.should be(container.logger)
    app.db.should be(container.database)
  end

  it "constructs chains of dependencies" do
    container.register(:app) { |c| App.new(c.logger) }
    container.register(:logger) { |c|
      log = Logger.new
      log.appender = c.logger_appender
      log
    }
    container.register(:logger_appender) { ConsoleAppender.new }
    container.register(:database) { MockDB.new }

    app = container.app
    logger = app.logger

    logger.appender.should be(container.logger_appender)
  end

  it "constructs literals" do
    container.register(:database) { |c| RealDB.new(c.username, c.userpassword) }
    container.register(:username) { "jim" }
    container.register(:userpassword) { "secret" }

    db = container.database
    db.username.should == "jim"
    db.password.should == "secret"
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

    it "reuses a service from the parent" do
      container.register(:gene) { :x }

      child.gene.should == :x
    end

    it "can overide a servie from the parent" do
      container.register(:gene) { :x }
      child.register(:gene) { :y }

      child.gene.should == :y
    end

    it "can override an indirect dependency" do
      container.register(:thing) { |c| c.real_thing }
      container.register(:real_thing) { "THING" }
      child.register(:real_thing) { "NEWTHING" }

      child.thing.should == "NEWTHING"
    end

    specify "the parent is uneffected by child registrations" do
      container.register(:gene) { :x }
      child.register(:gene) { :y }

      container.gene.should == :x
    end

    specify "multiple children do not interer with each other" do
      container.register(:gene) { :x }
      a = DIM::Container.new(container)
      b = DIM::Container.new(container)
      a.register(:gene) { :a }
      b.register(:gene) { :b }

      a.gene.should == :a
      b.gene.should == :b
    end
  end

end
