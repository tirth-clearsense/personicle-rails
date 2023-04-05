class MobilityController < ApplicationController
    require 'json'
    require 'ostruct'
    require 'date'
    before_action :require_user, :session_active?, :get_user_notifications
    helper_method :update_chart_by_date_range

  def index
    # if !params[:noti_id].nil? &&  !params[:noti_id].blank? 
    #   @notification_read = Notification.find_by(id: params[:noti_id]).mark_as_read!
    # end
    # add another request for specific data streams (step count)
    # use exercise for another chart
    st = 12.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
    et = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")

    # Update the chart using the start and end dates if present
    if params.has_key?(:start_date) && params.has_key?(:end_date) && params[:start_date].present? && params[:end_date].present?
      @start_date = Date.parse(params[:start_date]).strftime("%Y-%m-%d %H:%M:%S.%6N")
      @end_date = Date.parse(params[:end_date]).strftime("%Y-%m-%d %H:%M:%S.%6N")
      puts @start_date
      puts @end_date
        @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=@start_date, end_date=@end_date, hard_refresh=true,uid=session[:oktastate]['uid'])
        # puts "response"
        # puts @response
    else 
      @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=true,uid=session[:oktastate]['uid'])
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
      @mobility_aggregated = temporary_steps.map {|k,v| [k , v.sum {|r| r['value']}]}.to_h
      

      # Find how many total steps were taken in the last month
      tmp_steps = @response.select {|record| record['end_time'].to_datetime}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
      
      # puts tmp_steps
      @daily_steps = tmp_steps.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h
      
      @last_week_total_steps = @daily_steps.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
     
      # puts @last_week_total_steps 

     
        
        range_for_daily_steps = @daily_steps.keys.first.beginning_of_month..@daily_steps.keys.last.end_of_month
        

        @add_missing_days = {}
        range_for_daily_steps.each do |date|
          if @daily_steps.has_key?(date)
            @add_missing_days[date] = @daily_steps[date]
          else
            @add_missing_days[date] = 0
          end
        end

        
        @grouped_by_month = @daily_steps.group_by_month { |date, steps| date.strftime('%Y-%m-%d') }
       
        @all_months_with_steps = {}
        @grouped_by_month.each do |date, steps|
          year = date.year
          month = date.month

          start_date = Date.new(year, month, 1)
          end_date = (start_date >> 1) - 1
          @date_range = start_date..end_date
      
          # puts "Each Month Daily"
          @any_month_daily = @add_missing_days.select {|k,v| @date_range.include?(k)}
          # puts @any_month_daily
          @all_months_with_steps[date.strftime('%b %Y')] = @any_month_daily
        end
    else
      @processed_steps_data = {}
      @mobility_aggregated = {}
    end
  end

  # def pick_date
  #    # Get the start and end dates from the form parameters
  #   puts "pick_date params"
  #   puts params
  #   ###### Add conditions here to see if @start_date and @end_date are not null values
  #   @start_date = Date.parse(params[:start_date])
  #   @end_date = Date.parse(params[:end_date])
  #   puts @start_date
  #   puts @end_date

  #    # Update the chart using the start and end dates if present
  #   if @start_date.present? && @end_date.present?
  #     update_chart_by_date_range(@start_date, @end_date)
  #   else
  #     # Redirect to mobility page wher it uses pre-set dates from the index
  #     redirect_to pages_mobility_path
  #   end
  # end

  # def update_chart_by_date_range(start_date, end_date)

  #   puts "start date and end date"
  #   puts st=start_date.strftime("%Y-%m-%d %H:%M:%S.%6N")
  #   puts et=end_date.strftime("%Y-%m-%d %H:%M:%S.%6N")

  #     @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=true,uid=session[:oktastate]['uid'])
  #     puts "response"
  #     # puts @response

  #         # Find how many total steps were taken in the last month
  #         tmp_steps = @response.select {|record| record['end_time'].to_datetime}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
  #         puts "Temporary Steps over Chosen Date Range"
  #         # puts tmp_steps
  #         @daily_steps = tmp_steps.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h
  #         puts "Daily Steps For Past 12 Months"
  #         # puts @daily_steps
  #         @last_week_total_steps = @daily_steps.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
  #         puts "Number of Steps Taken All Last Week"
  #         # puts @last_week_total_steps 
    
  #         puts "Add the date and value of 0 for days where there were no steps"
            
  #           range_for_daily_steps = @daily_steps.keys.first.beginning_of_month..@daily_steps.keys.last.end_of_month
  #           puts "Range for Daily Steps (All Chosen Months)"
  #           puts range_for_daily_steps
    
  #           @add_missing_days = {}
  #           range_for_daily_steps.each do |date|
  #             if @daily_steps.has_key?(date)
  #               @add_missing_days[date] = @daily_steps[date]
  #             else
  #               @add_missing_days[date] = 0
  #             end
  #           end
    
            
  #           @grouped_by_month = @daily_steps.group_by_month { |date, steps| date.strftime('%Y-%m-%d') }
  #           puts "Grouped By Month"
  #           puts @grouped_by_month
    
    
    
  #           @all_months_with_steps = {}
  #           @grouped_by_month.each do |date, steps|
  #             puts "Get the Date Range for Each Month"
  #             year = date.year
  #             month = date.month
    
  #             start_date = Date.new(year, month, 1)
  #             end_date = (start_date >> 1) - 1
  #             @date_range = start_date..end_date
  #             puts @date_range
  #             puts "#{date.strftime('%b %Y')}: #{@date_range}"
  #             # puts "Each Month Daily"
  #             @any_month_daily = @add_missing_days.select {|k,v| @date_range.include?(k)}
  #             # puts @any_month_daily
  #             @all_months_with_steps[date.strftime('%b %Y')] = @any_month_daily
  #           end

  #           puts "Each Month's Set Accessed Using date.strftime('%b %Y')"
  #           puts @all_months_with_steps
  #           puts "Hash with Zero Steps on Missing Dates"
  #           puts @add_missing_days

  #           # Re-render the page with updated data
  #           render :index


  #   # render turbo_stream:
  #   # turbo_stream.replace("chart_datepicker_frame",
  #   # partial: "/pages/pick_date",
  #   # locals: { start_date: start_date, end_date: end_date, chart_data: @all_months_with_steps })

  #   # all_months_by_month_year_data = @all_months_with_steps


  # end

  # def last_month
  #   st = 3.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
  #   et = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")
  #   if params.has_key?(:refresh) && params[:refresh]=="hard_refresh"
  #     @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=true,uid=session[:oktastate]['uid'])
  #     # puts "response"
  #     # puts @response
  #   else
  #     @response = FetchData.get_datastreams(session,source="google-fit",datatype="com.personicle.individual.datastreams.interval.step.count",start_date=st, end_date=et, hard_refresh=false,uid=session[:oktastate]['uid'])
  #     # puts "response"
  #     # puts @response
  #   end 
  
  #   tmp_steps = @response.select {|record| record['end_time'].to_datetime > 30.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
  #   @daily_steps = tmp_steps.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h

  #   chart_data = @daily_steps.map { |k, v| [k.strftime("%Y-%m-%d"), v] }
  #   first_bar_start_date = Date.parse(chart_data[0][0])
  #   last_month_start_date = first_bar_start_date - 1.months
  #   puts "Last Month Start Date"
  #   puts last_month_start_date
  #   last_month_end_date = first_bar_start_date - 1.day
  #   puts "Last Month End Date"
  #   puts last_month_end_date
  #   # Filter chart_data to only include data for the last month
  #   chart_data = chart_data.select { |date, value| Date.parse(date) >= last_month_start_date && Date.parse(date) <= last_month_end_date }
    
  #   last_month_total_steps = @response.select { |record| Date.parse(record['end_time']) >= last_month_start_date && Date.parse(record['end_time']) <= last_month_end_date }.map { |rec| [Date.parse(rec['end_time']), rec['value']] }.group_by { |r| r[0] }.to_h
  #   puts "Last Month Steps"
  #   puts last_month_total_steps
  #   @last_month_daily_steps = last_month_total_steps.map { |k, v| [k, v.sum { |r| r[1] }] }.to_h
  #   puts "Last Month Daily Steps"
  #   puts @last_month_daily_steps
  #   @daily_steps = @last_month_daily_steps

  #   last_two_months_start_date = first_bar_start_date - 2.months
  #   last_two_months_end_date = first_bar_start_date - 1.month
  #   last_two_months_data = @response.select { |record| Date.parse(record['end_time']) >= last_two_months_start_date && Date.parse(record['end_time']) <= last_month_end_date }.map { |rec| [Date.parse(rec['end_time']), rec['value']] }.group_by { |r| r[0] }.to_h
  #   @last_two_months_daily_steps = last_two_months_data.map { |k, v| [k, v.sum { |r| r[1] }] }.to_h
  
  #   respond_to do |format|
  #     format.html { redirect_back(fallback_location: root_path) }
  #     format.json { render json: { last_two_months_data: @last_two_months_daily_steps, last_month_data: @last_month_daily_steps, current_month_data: @daily_steps }.to_json }
  #   end
  # end
end
