class MobilityController < ApplicationController
    require 'json'
    require 'ostruct'
    require 'date'
    before_action :require_user, :session_active?, :get_user_notifications

  def index
    # if !params[:noti_id].nil? &&  !params[:noti_id].blank? 
    #   @notification_read = Notification.find_by(id: params[:noti_id]).mark_as_read!
    # end
    # add another request for specific data streams (step count)
    # use exercise for another chart
    st = 3.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
    et = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")
    if params.has_key?(:refresh) && params[:refresh]=="hard_refresh"
      @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=true,uid=session[:oktastate]['uid'])
      # puts "response"
      # puts @response
    else
      @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=false,uid=session[:oktastate]['uid'])
      # puts "response"
      # puts @response
    end 
 

    if !@response.empty?

      @steps_data_raw = []
      @mobility_by_day= []
      @response.each { |record|
        timestamp_data = record['end_time'].to_datetime
        @steps_data_raw.push({'minute_value' => timestamp_data.minute + timestamp_data.hour * 60, 'weekday' => record['end_time'].to_datetime.strftime("%A"), 'value' => record['value']})
        # @mobility_by_day.push({'timestamp' => timestamp_data.to_date, 'value' => record['value']})
        # puts record['value'].class
        # puts timestamp_data, timestamp_data.class, timestamp_data.to_date.class, type(record['timestamp'])
      }
        # puts mobility_by_day
        
      temporary_steps = @response.group_by_day{|rec| rec['end_time'].to_datetime}.to_h
      @mobility_aggregated = temporary_steps.map {|k,v| [k, v.sum {|r| r['value']}]}.to_h
      # puts @mobility_aggregated

      weekly_steps = @response.group_by_week{|rec| rec['end_time'].to_datetime}.to_h
      @weekly_aggregated = weekly_steps.map {|k,v| [k, v.sum {|r| r['value']}]}
      # puts @weekly_aggregated

      all_minutes = [*0..1439]
      all_days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

      weekday_grouped_data = @steps_data_raw.group_by { |rec| rec['weekday']}.to_h
      
      # puts weekday_grouped_data

      @processed_steps_data = {}
      all_days.each { |week_day|
        # puts week_day
        current_day_data = weekday_grouped_data[week_day]
        if !current_day_data.nil? 
          summarized_data = current_day_data.group_by {|rec| rec['minute_value']/30}.map {|k, v| [k, (v.size>0)?(v.sum {|r| r['value']}.to_f/90) : 0]}.to_h
          # summarized_data = current_day_data.group_by {|rec| rec[0]}.to_h {|k, v| [k, v.sum {|r| r[1]}]}
          @processed_steps_data[week_day] = summarized_data
        end
      }

      temporary_steps = @response.group_by_day{|rec| rec['end_time'].to_datetime}.to_h 
      @mobility_aggregated = temporary_steps.map {|k,v| {k => v.sum {|r| r['value']}}}
     

      # Find how many total steps were taken in the last week
      tmp_steps = @response.select {|record| record['end_time'].to_datetime > 30.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
      @daily_steps = tmp_steps.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h
      
      @last_week_total_steps = @daily_steps.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
     
    else
      @processed_steps_data = {}
      @mobility_aggregated = {}
    end
  end
end
