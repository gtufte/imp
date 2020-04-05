require 'httparty'
require 'rubyserial'

class Imp

  include HTTParty

  base_uri "https://#{ENV['SENSU_HOST']}"
  @@basic_auth = {:username => ENV['SENSU_USER'], :password => ENV['SENSU_PASSWORD']}
  @access_token = ''
  @refresh_token = ''
  @incidents = []
  @silenced_incidents = []
  @filtered_incidents = []

  def auth(refresh = false)
    if (refresh)
      r = post(
        "/auth/token",
        verify: false,
        :body => {:refresh_token => @refresh_token}.to_json,
        :headers => {"Authorization" => "Bearer #{@access_token}"})
    else
      r = self.class.get("/auth", verify: false, :basic_auth => @@basic_auth)
    end
    @access_token = r['access_token']
    @refresh_token = r['refresh_token']
  end
  
  def getAccessToken
    return @access_token
  end

  def getRefreshToken
    return @refresh_token
  end
  
  def getIncidents
    return @incidents
  end

  def fetchIncidents
    @incidents = self.class.get(
      "/api/core/v2/namespaces/#{ENV['SENSU_NAMESPACE']}/events",
       verify: false,
       :query => "fieldSelector=event.check.status != '0'",
       :headers => {"Authorization" => "Bearer #{@access_token}"})
  end

  def fetchSilencedIncidents
    @silenced_incidents = self.class.get(
      "/api/core/v2/namespaces/#{ENV['SENSU_NAMESPACE']}/silenced",
       verify: false,
       :headers => {"Content-Type" => "application/json", "Authorization" => "Bearer #{@access_token}"})
  end

  def filterIncidents
    self.fetchIncidents
    self.fetchSilencedIncidents
    @filtered_incidents = []
    @incidents.each do |e|
      event_is_silenced = false
      @silenced_incidents.each do |s|
        if s['metadata']['name'].match?(/^entity:#{e['entity']['metadata']['name']}:#{e['check']['metadata']['name']}$/) ||
           s['metadata']['name'].match?(/^entity:#{e['entity']['metadata']['name']}:\*/) ||
           s['metadata']['name'].match?(/^\*:#{e['check']['metadata']['name']}$/)
          event_is_silenced = true
          break
        end
      end
      if not event_is_silenced
        @filtered_incidents.push("#{e['entity']['metadata']['name']} #{e['check']['metadata']['name']} #{e['check']['status']}")
      end
    end
  end

  def getFilteredIncidents()
    return @filtered_incidents
  end

  def self.mostSevereIncident(incidents)
    incidents.each do |e|
      if (e.reverse =~ /2 /)
        return 2
      end
    end
    incidents.each do |e|
      if (e.reverse =~ /1 /)
        return 1
      end
    end
    return 3
  end
  
  def self.fitstatColorSeq(dev, a = nil, b = nil, i = "0300")
    dev.write("B#{a}-#{i}#{b}-#{i}\r\n")
    sleep(3)
    dev.write("#{b}\r\n")
  end

end

puts "INFO: Connecting to fitstat"
fitstat = Serial.new '/dev/fitstat'
puts "INFO: Device found!"

fitstat_color_init_high = "#F000F0"
fitstat_color_init_low = "#100010"
fitstat_color_critical_high = "#FF0000"
fitstat_color_critical_low = "#110000"
fitstat_color_warning_high = "#BB1100"
fitstat_color_warning_low = "#551100"
fitstat_color_unknown_high = "#00FFFF"
fitstat_color_unknown_low = "#001111"
fitstat_color_ok_high = "#00FF00"
fitstat_color_ok_low = "#001100"

imp = Imp.new
puts "INFO: Acquiring API access token from Sensu"
imp.auth
puts "INFO: Initial fetch of all unsilenced incidents"
imp.filterIncidents
Imp.fitstatColorSeq(fitstat, fitstat_color_init_high, fitstat_color_init_low)
sleep(60)

i = 0
last_status = 0
while true do
  # acquire new access token every 4 minutes
  if (i == 4)
    imp.auth
    i = 0
  end
  tmp = imp.getFilteredIncidents
  imp.filterIncidents
  new_incidents = tmp - imp.getFilteredIncidents
  if (new_incidents.any?)
    most_severe_incident = Imp.mostSevereIncident(new_incidents)
    puts "There are new incidents!"
    puts tmp - imp.getFilteredIncidents
    if (most_severe_incident == 2 and last_status != 2)
      Imp.fitstatColorSeq(fitstat, fitstat_color_critical_high, fitstat_color_critical_low)
      last_status = 2
    elsif (most_severe_incident == 1 and last_status != 1)
      Imp.fitstatColorSeq(fitstat, fitstat_color_warning_high, fitstat_color_warning_low)
      last_status = 1
    elsif (most_severe_incident == 3 and last_status != 3)
      Imp.fitstatColorSeq(fitstat, fitstat_color_unknown_high, fitstat_color_unknown_low)
      last_status = 3
    end
  elsif (tmp.empty? and last_status != 0)
    Imp.fitstatColorSeq(fitstat, fitstat_color_ok_high, fitstat_color_ok_low)
    last_status = 0
  end
  sleep(60)
  i += 1
end
