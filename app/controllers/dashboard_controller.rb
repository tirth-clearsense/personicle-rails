class DashboardController < ApplicationController
  require 'json'
  require 'ostruct'
  require 'date'
  before_action :require_user, :session_active?, :get_user_notifications
  before_action :set_locale

  protected def set_locale
    I18n.locale = params[:locale] || # 1: use request parameter, if available
      session[:locale] ||            # 2: use the value saved in iurrent session
      I18n.default_locale            # last: fallback to default locale
  end

  protected def save_locale
    session[:locale] = I18n.locale
  end

  def index
    # puts params
    puts session[:oktastate]['credentials']['token']
    # if !params[:noti_id].nil? &&  !params[:noti_id].blank? 
    #   @notification_read = Notification.find_by(id: params[:noti_id]).mark_as_read!
    # end
    st = 3.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
    et = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")

    if params[:refresh]=="hard_refresh"
      puts "hard refresh"
      @response = FetchData.get_events(session,event_type=false,st,et,hard_refresh=true,uid=session[:oktastate]['uid'])
      @response_step = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, is_hard_refresh=true,uid=session[:oktastate]['uid'])
      @response_weight = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.weight",start_date=st, end_date=et, hard_refresh=true,uid=session[:oktastate]['uid'])
      @response_calories = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.interval.total_calories",start_date=st, end_date=et, is_hard_refresh=true,user_id=session[:oktastate]['uid'])
     
    else
      puts "not hard refresh"
      @response = FetchData.get_events(session,event_type=false,st,et,hard_refresh=false,uid=session[:oktastate]['uid'])
      @response_step = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=false,uid=session[:oktastate]['uid'])
      @response_weight = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.weight",start_date=st, end_date=et, hard_refresh=false,uid=session[:oktastate]['uid'])
      @response_calories = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.interval.total_calories",start_date=st, end_date=et, is_hard_refresh=false,user_id=session[:oktastate]['uid'])

    end 
   
    if !@response.empty?
      # @response = JSON.parse(res,object_class: OpenStruct)
      # last_month_total_sleep, last_month_sleep_events
      # last_week_total_sleep, last_week_sleep_events
      
    respond_to do |format|
      format.html
      format.json { render json: UserEventsDatatable.new(params) }
    end

      @sleep_events = @response.select {|event| event['event_name'] == 'Sleep'}
      # duration is in milliseconds in the data packet
      @last_month_total_sleep = @sleep_events.select {|event| event['start_time'].to_datetime > 30.days.ago}.sum {|event| event['parameters']['duration']}/(60*1000)
      @last_month_sleep_event = @sleep_events.select {|event| event['start_time'].to_datetime > 30.days.ago}.size
      @last_week_total_sleep = @sleep_events.select {|event| event['start_time'].to_datetime > 7.days.ago}.sum {|event| event['parameters']['duration']}/(60*1000)
      @last_week_sleep_event = @sleep_events.select {|event| event['start_time'].to_datetime > 7.days.ago}.size
      
      @last_week_average_sleep = @last_week_sleep_event>0? @last_week_total_sleep/@last_week_sleep_event:0
      @last_month_average_sleep = @last_month_sleep_event>0? @last_month_total_sleep/@last_month_sleep_event:0
      # puts @response
      # puts @last_week_sleep_event
    end

    if !@response_calories.empty?
    
      tmp_calories = @response_calories.select {|record| record['end_time'].to_datetime > 30.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
      @daily_calories = tmp_calories.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h

      @last_month_total_calories = @daily_calories.select {|k,v| k > 30.days.ago}.sum {|k,v| v}
     
      @last_month_calories_days = @daily_calories.select {|k,v| k > 30.days.ago}.size

      @last_week_total_calories = @daily_calories.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
    
      @last_week_calories_days = @daily_calories.select {|k,v| k > 7.days.ago}.size
      

      @last_week_average_calories = @last_week_calories_days>0? @last_week_total_calories/@last_week_calories_days:0
     
      @last_month_average_calories = @last_month_calories_days>0? @last_month_total_calories/@last_month_calories_days:0
     
      
      @response_calories_prev_week = @response_calories.select {|record| record['end_time'].to_datetime > 7.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
     

    end
 

    if !@response_step.empty?
    
      tmp_steps = @response_step.select {|record| record['end_time'].to_datetime > 30.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
      @daily_steps = tmp_steps.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h
      # puts @daily_steps

      @last_month_total_steps = @daily_steps.select {|k,v| k > 30.days.ago}.sum {|k,v| v}
      @last_month_steps_days = @daily_steps.select {|k,v| k > 30.days.ago}.size
      @last_week_total_steps = @daily_steps.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
      @last_week_steps_days = @daily_steps.select {|k,v| k > 7.days.ago}.size

      @last_week_average_steps = @last_week_steps_days>0? @last_week_total_steps/@last_week_steps_days:0
      @last_month_average_steps = @last_month_steps_days>0? @last_month_total_steps/@last_month_steps_days:0
    end

    if !@response_weight.empty?
      #puts @response_weight
      # puts 'Weight Response'
      tmp_weight = @response_weight.group_by_day{|rec| rec['timestamp'].to_datetime}.to_h
      @daily_weight = tmp_weight.map {|k,v| [k, v.sum {|r| r['value']}]}.to_h
      # puts 'Daily Weight'
      # puts @daily_weight
    end

    if Rails.env.production?
      ip = "#{request.ip}"
      results = Geocoder.search(ip)
      # puts results.first.coordinates
      # puts ip
      # @latitude = request.safe_location.latitude
      # @longitude = request.safe_location.longitude
      @latitude =  results.first.coordinates[0]
      @longitude =  results.first.coordinates[1]
      # puts @latitude
      # puts @longitude

      data={
            "individual_id": session[:oktastate]["uid"],
            "streamName": "com.personicle.individual.datastreams.location",
            "source": "PERSONICLE_WEB_APP",
            "dataPoints":[{
              "timestamp": Time.now.getutc,
              "value": [{"latitude": @latitude, "longitude": @longitude}]
            }]
        }

        # puts data.to_json
        res = RestClient::Request.execute(:url => "https://api.personicle.org/data/write/datastream/upload", :payload => data.to_json, :method => :post, headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']}", content_type: :json})
           
    end

    # puts @response
  end

  def delete_event
    # url = "https://api.personicle.org/data/write/event/delete"?user_id=userid&event_id=some_event_id;another_event_id
    # RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']} "}, :method => :delete, ),object_class: OpenStruct)
    # params[:select-all] = select-all_value
    events = JSON.parse(params[:selected_events])
   
    
    if !events.nil?
      events = events.join(";") 
      url = "https://staging.personicle.org/data/write/event/delete?user_id=#{session[:oktastate]['uid']}&event_id=#{events}"
      res =  JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']} "}, :method => :delete,:verify_ssl => false ),object_class: OpenStruct)
      redirect_to pages_dashboard_path, refresh:"hard_refresh"
    end
  end

  def geocode
    
  end
  def update_event
    # Inside update make 2 API calls
    # 1. Delete event api
    # 2. Add events api
      events = JSON.parse(params[:selected_events])
    
    
      if !events.nil?
        events = events.join(";")
        url = "https://api.personicle.org/data/write/event/delete?user_id=#{session[:oktastate]['uid']}&event_id=#{events}"
        res =  JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']} "}, :method => :delete,:verify_ssl => false ),object_class: OpenStruct)
      end
  
      # ## Get Updated Event
      updated_events = JSON.parse(params[:updated_events])
  
      for index in 0 ... updated_events.size
        # puts "array[#{index}] = #{array[index].inspect}"
        updated_events[index][:individual_id] = session[:oktastate]['uid']
      end
  
      res = RestClient::Request.execute(:url => ENV['EVENT_UPLOAD'], :payload => updated_events.to_json, :method => :post, headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']}", content_type: :json})  
      # puts "Params"
      # puts params
      redirect_to pages_dashboard_path, refresh:"hard_refresh"
    end

  def geocode
    
  end

 
end
