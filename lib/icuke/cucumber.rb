require 'nokogiri'

require 'icuke/simulator'
require 'icuke/simulate'

class ICukeWorld
  include ICuke::Simulate::Gestures
  
  attr_reader :response
  
  def initialize
    @simulator = ICuke::Simulator.new
  end
  
  def launch(application, options = {})
    @simulator.launch(application, options)
  end
  
  def quit
    @simulator.quit
  end
  
  def page
    @xml ||= Nokogiri::XML::Document.parse(response).root
  end
  
  def response
    @response ||= @simulator.view
  end
  
  def record
    @simulator.record
  end
  
  def tap(label, options = {}, &block)
    options = {
      :pause => true
    }.merge(options)
    
    unless element = page.xpath(%Q{//*[(contains(@traits, "button") or contains(@traits, "updates_frequently") or contains(@traits, "keyboard_key")) and @label="#{label}" and frame]}).first
      raise %Q{No element labelled "#{label}" found in: #{response}}
    end
    
    # This seems brittle, revist how to fetch the frame without relying on it being the only child
    frame = element.child
    
    # Hit the element in the middle
    x = frame['x'].to_f + (frame['width'].to_f / 2)
    y = frame['y'].to_f + (frame['height'].to_f / 2)
    
    @simulator.fire_event(Tap.new(x, y, options))
    
    sleep(options[:pause] ? 1 : 0.2)
    
    refresh
    
    yield element if block_given?
  end
  
  def type(textfield, text, options = {})
    tap(textfield, :hold_for => 0.75) do |field|
      if field['value']
        tap('Select All')
        tap('Delete')
      end
    end
    
    text.split('').each do |c|
      next_keyboard_keys = ['shift', 'next keyboard', 'shift']
      
      begin
        tap(c, :pause => false)
      rescue Exception => e
        until next_keyboard_keys.empty?
          begin
            tap(next_keyboard_keys.shift, :pause => false)
            retry
          rescue
          end
        end
        raise e
      end
    end

    # From UIReturnKeyType
    # Should probably sort these in rough order of likelyhood?
    return_keys = ['return', 'go', 'google', 'join', 'next', 'route', 'search', 'send', 'yahoo', 'done', 'emergency call']
    return_keys.each do |key|
      begin
        tap(key)
        return
      rescue
      end
    end
  end
  
  def set_application_defaults(defaults)
    @simulator.set_defaults(defaults)
  end
  
  private
  
  def refresh
    @response = nil
    @xml = nil
  end
end

World do
  ICukeWorld.new
end

LIBICUKE = File.expand_path(File.dirname(__FILE__) + '/../../ext/iCuke/libicuke.dylib')

Given /^(?:"([^\"]*)" from )?"([^\"]*)" is loaded in the simulator(?: using sdk (.*))?$/ do |target, project, sdk|
  launch File.expand_path(project),
         :target => target,
         :env => { 'DYLD_INSERT_LIBRARIES' => LIBICUKE }
end

Then /^I should see "([^\"]*)"$/ do |text|
  if page.xpath("//*[contains(., '#{text}') or contains(@label, '#{text}') or contains(@value, '#{text}')]").empty?
    raise %Q{Content "#{text}" not found in: #{response}}
  end
end

Then /^I should not see "([^\"]*)"$/ do |text|
  unless page.xpath("//*[contains(., '#{text}') or contains(@label, '#{text}') or contains(@value, '#{text}')]").empty?
    raise %Q{Content "#{text}" was found but was not expected in: #{response}}
  end
end

When /^I tap "([^\"]*)"$/ do |label|
  tap(label)
end

When /^I type "([^\"]*)" in "([^\"]*)"$/ do |text, textfield|
  type(textfield, text)
end

Then /^I put the phone into recording mode$/ do
  record
end

Then /^show me the screen$/ do
  puts response
end