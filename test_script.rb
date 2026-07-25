puts "ENV FRONTEND_URL: #{ENV['FRONTEND_URL']}"
w = Channel::WebWidget.first
if w
  puts "SCRIPT: #{w.web_widget_script}"
else
  puts "NO WIDGET FOUND"
end
