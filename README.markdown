# DIM: Dependency Injection - Minimal

DIM is [Jim Weirich's](http://onestepback.org) minimalistic dependency injection framework, maintained in 
gem form by [Mike Subelsky](http://subelsky.com).

Dependency injection lets you organize all of your app's object setup code in one place by creating a
container. Whenver an object in your application needs access to another object or resource, it asks
the container to provide it (using lazily-evaluated code blocks).

When testing your code, you can either stub out services on the container, or you can provide a substitute container.

## Example

The following could be in a "lib.init.rb" file or in a Rails app, "config/initializers/container.rb":

    require "dim"
    require "logger"
    require 'game'
    require 'event_handler'
    require 'transmitter'

    ServerContainer = Dim::Container.new

    ServerContainer.register(:transmitter) { |c| Transmitter.new(c.logger) }

    ServerContainer.register(:event_handler) do |c|
      eh = EventHandler.new
      eh.transmitter = c.transmitter
      eh.logger = c.logger
      eh
    end

    ServerContainer.register(:listening_host) { "0.0.0.0" }
    ServerContainer.register(:listening_port) { "8080" }

    ServerContainer.register(:game) do |c| 
      game = Game.new
      game.logger = c.logger
      game.event_handler = c.event_handler
      game.host = c.listening_host
      game.port = c.listening_port
      game
    end

    ServerContainer.register(:root_dir) do |c|
      Pathname.new(File.expand_path(File.dirname(__FILE__) + "/.."))
    end

    ServerContainer.register(:log_file_path) do |c|
      "#{c.root_dir}/log/#{c.environment}.log"
    end

    ServerContainer.register(:logger) do |c|
      Logger.new(c.log_file_path)
    end

Using the above code elsewhere in the app, when you want a reference to the app's logger object:

    ServerContainer.logger.info("I didn't have to setup my own logger")

Or if you wanted access to the game instance created during setup (which already is configured with everything it needs):

    current_game = ServerContainer.game

If you don't like creating even the one dependency on the global constant ServerContainer, you could 
inject ServerContainer itself into your objects like so:
    
    World.new(GameContainer)
    
## More Background

Jim wrote a [nice article](http://onestepback.org/index.cgi/Tech/Ruby/DependencyInjectionInRuby.rdoc) explaining
the rationale for this code and how it works. Also check out [his slides](http://onestepback.org/articles/depinj/).

# License

DIM is available under the MIT license (see the file MIT-LICENSE for details).
