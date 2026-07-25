w = Channel::WebWidget.find_by(website_token: 'd8h7oSc7ssXEB33r6dZEsyNH')
if w
  puts "SCRIPT: #{w.web_widget_script}"
else
  puts "NOT FOUND"
end
