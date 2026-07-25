token = 'd8h7oSc7ssXEb33r6dZEsyNH'
widget = Channel::WebWidget.find_by(website_token: token)
if widget
  puts "FOUND WIDGET ID: #{widget.id}"
  puts "INBOX ID: #{widget.inbox.id}"
  puts "ALLOW MOBILE WEBVIEW: #{widget.allow_mobile_webview?}"
else
  puts "WIDGET NOT FOUND"
end
