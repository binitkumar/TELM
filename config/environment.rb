require File.join(File.dirname(__FILE__), 'boot')


RAILS_GEM_VERSION = '2.3.11' unless defined? RAILS_GEM_VERSION
if Gem::VERSION >= "1.3.6"
    module Rails
        class GemDependency
            def requirement
                r = super
                (r == Gem::Requirement.default) ? nil : r
            end
        end
    end
end
Rails::Initializer.run do |config|
  config.time_zone = 'UTC'
  config.gem 'declarative_authorization', :source => 'http://gemcutter.org'
  config.gem 'searchlogic', :version=> '2.4.27'

  config.load_once_paths += %W( #{RAILS_ROOT}/lib )
  config.load_paths += Dir["#{RAILS_ROOT}/app/models/*"].find_all { |f| File.stat(f).directory? }

  config.plugins = [:paperclip,:all]
end
