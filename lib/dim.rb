#!/usr/bin/env ruby
#--
# Copyright 2004, 2005 by Jim Weirich (jim@weirichhouse.org).
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#++
#
# = Dependency Injection - Minimal (DIM)
#
# The DIM module provides a minimal dependency injection framework for
# Ruby programs.
#
# Example:
#
#   require 'dim'
#
#   container = DIM::Container.new
#   container.register(:log_file) { "logfile.log" }
#   container.register(:logger) { |c| FileLogger.new(c.log_file) }
#   container.register(:application) { |c|
#     app = Application.new
#     app.logger = c.logger
#     app
#   }
#
#   c.application.run
#
module DIM
  # Thrown when a service cannot be located by name.
  class MissingServiceError < StandardError; end

  # Thrown when a duplicate service is registered.
  class DuplicateServiceError < StandardError; end

  # DIM::Container is the central data store for registering services
  # used for dependency injuction.  Users register services by
  # providing a name and a block used to create the service.  Services
  # may be retrieved by asking for them by name (via the [] operator)
  # or by selector (via the method_missing technique).
  #
  class Container
    # Create a dependency injection container.  Specify a parent
    # container to use as a fallback for service lookup.
    def initialize(parent=nil)
      @services = {}
      @cache = {}
      @parent = parent || Container
    end

    # Register a service named +name+.  The +block+ will be used to
    # create the service on demand.  It is recommended that symbols be
    # used as the name of a service.
    def register(name, &block)
      if @services[name]
        fail DuplicateServiceError, "Duplicate Service Name '#{name}'"
      end
      @services[name] = block
    end

    # Lookup a service by name.  Throw an exception if no service is
    # found.
    def [](name)
      @cache[name] ||= service_block(name).call(self)
    end

    # Lookup a service by message selector.  A service with the same
    # name as +sym+ will be returned, or an exception is thrown if no
    # matching service is found.
    def method_missing(sym, *args, &block)
      self[sym]
    end

    # Return the block that creates the named service.  Throw an
    # exception if no service creation block of the given name can be
    # found in the container or its parents.
    def service_block(name)
      @services[name] || @parent.service_block(name)
    end

    # Searching for a service block only reaches the Container class
    # when all the containers in the hierarchy search chain have no
    # entry for the service.  In this case, the only thing to do is
    # signal a failure.
    def self.service_block(name)
      fail(MissingServiceError, "Unknown Service '#{name}'")
    end
  end
end
