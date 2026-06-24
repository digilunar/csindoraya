# config/initializers/rack_fix.rb
if defined?(Rack) && !defined?(Rack::File)
  Rack::File = Rack::Files
end
