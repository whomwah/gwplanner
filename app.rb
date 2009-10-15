require 'rubygems' 
require 'nokogiri'
require 'open-uri'
require 'icalendar'
require 'date'
require 'rack/cache'

include Icalendar

use Rack::Cache, 
  :verbose => true, 
  :metastore => "file:cache/meta", 
  :entitystore => "file:cache/body" 

FEED_URI = 'http://www.bbc.co.uk/gardening/calendar/_xml/tasks.xml'

class Garden
	attr_reader :sections

  def initialize
    @doc = nil
    @sections = {} 
    @cal = Calendar.new
    @cal.custom_property("X-WR-TIMEZONE;VALUE=TEXT", 'Europe/London')

    fetch_data 
    create_sections
  end

  def build_calendar(s = '')
    # handle any section data
    s_data = s.downcase.split(',') 

    if s_data.empty?
      d_str = 'All our gardening tips for the year' 
    else 
      d_str = "#{s_data.join(', ').capitalize} tips for the year" 
    end

    # add the calendar title and description
    @cal.custom_property("X-WR-CALNAME;VALUE=TEXT", "Gardeners' planner from the BBC")
    @cal.custom_property("X-WR-CALDESC;VALUE=TEXT", d_str)


    # add the tasks
    n = Time.now
    @doc.xpath('//tftd/tsks/t').each do |task|
      section = section_for(task.xpath('cs'))
      next if !s_data.empty? and section and !s_data.include?(section.downcase)  

      start_month = task.xpath('b').first['m'].to_i 
      start_day   = task.xpath('b').first['d'].to_i
      end_month   = task.xpath('e').first['m'].to_i
      end_day     = task.xpath('e').first['d'].to_i
      
      @cal.event do
        dtstart       Date.new(n.year, start_month, start_day)
        dtend         Date.new(n.year, end_month, end_day)
        summary       task.xpath('tl').first.content   
        description   task.xpath('d').first.content 
        location      section
        url           task.xpath('r').first.content 
        klass         "PRIVATE"
      end
    end
  end

  def create_sections
    @doc.xpath('//tftd/cs/c').each do |section|
      @sections[section['id']] = section['nm']
    end
  end

  def section_for(data)
    return '' unless data.first
    @sections[data.first.content]
  end

  def fetch_data
    @doc = Nokogiri::XML(open(FEED_URI))
  end

  def to_ical
    @cal.to_ical
  end

end

get('/planner.ics') { 
  response["Cache-Control"] = "max-age=86400, public" 
  c = Garden.new
  if s = params["s"]
    c.build_calendar(s)
  else
    c.build_calendar
  end
  c.to_ical
}

get('/') { 
  response["Cache-Control"] = "max-age=86400, public" 
  content_type 'text/plain', :charset => 'utf-8'
  c = Garden.new
  c.build_calendar
  sc = c.sections.values.map {|s| s.gsub(/\s+/, '').downcase}.sort.join("\n")
  <<EOF
BBC Gardeners' Planner as an .ics calendar
------------------------------------------

Find tips for your garden any day of the year. You can subscribe to
with the complete planner, or with optional sections listed at the bottom:

http://#{request.env['HTTP_HOST']}/planner.ics                         # full planner
http://#{request.env['HTTP_HOST']}/planner.ics?s=pond,trees,wildlife   # custom planner

#{sc} 
EOF
}
