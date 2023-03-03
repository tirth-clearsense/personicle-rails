class PhysicianController < ApplicationController
    before_action :require_user, :session_active?, :is_user_physician?, except: [:create_account]
    before_action :get_user_notifications
    
    def index
        
        logger.info session[:oktastate]['credentials']['token']
        @physician = Physician.find_by(user_id: session[:oktastate]["uid"])
    end

    def get_user_data
        
        if request.get? && params["data_for_user"].blank?
            return redirect_to pages_dashboard_physician_path
        end
        @physician = Physician.find_by(user_id: session[:oktastate]["uid"])
        st = 3.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
        et = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")
        
        # puts ((Time.now + 2.days).strftime("%Y-%m-%d %H:%M:%S.%6N")  )
       
        if params[:refresh]=="hard_refresh"
            @user_data =  FetchData.get_events(session,event_type="Sleep",st,et,hard_refresh=true, uid=params["data_for_user"])
            @user_events = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.interval.step.count",st, et, hard_refresh=true,uid=params["data_for_user"])
            @user_hr  = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.heartrate",st, et, hard_refresh=true,uid=params["data_for_user"])
            @user_responses  = FetchData.get_datastreams(session,source=nil,data_type="com.personicle.individual.datastreams.subjective.physician_questionnaire",st, et, hard_refresh=true,uid=params["data_for_user"])
            @response_calories = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.interval.total_calories",start_date=st, end_date=et, hard_refresh=true,uid=params["data_for_user"])
        else
            @user_data =  FetchData.get_events(session,event_type="Sleep",st,et,hard_refresh=false, uid=params["data_for_user"])
            @user_events = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.interval.step.count",st, et, hard_refresh=false,uid=params["data_for_user"])
            @user_hr  = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.heartrate",st, et, hard_refresh=false,uid=params["data_for_user"])
            @user_responses  = FetchData.get_datastreams(session,source=nil,data_type="com.personicle.individual.datastreams.subjective.physician_questionnaire",st, et, hard_refresh=false,uid=params["data_for_user"])
            @response_calories = FetchData.get_datastreams(session,source="google-fit",data_type="com.personicle.individual.datastreams.interval.total_calories",start_date=st, end_date=et, hard_refresh=false,uid=params["data_for_user"])
            
        end
        
         if !@user_responses.empty?
            # puts @user_responses/
            responses_for_current_physician = @user_responses.filter {|resp| resp['source'].split(':')[1] == session[:oktastate]['uid']} 
            timestamped_responses = []
            responses_for_current_physician.each do |rec|
                    current_timestamp = rec['timestamp']
                    responses = rec['value']
                    responses.each do |resp|
                        timestamped_responses.push({'timestamp'=> current_timestamp, 'question_id'=> resp['question_id'], 'response' => resp['value'], 'response_type' => resp['response_type']})
                    end
            end

            question_indexed_responses = timestamped_responses.group_by {|rec| [rec['question_id'], rec['timestamp'].to_date, rec['response'], rec['response_type']]}.to_h
            image_responses = timestamped_responses.filter {|rec| rec['response_type'] == 'image'}.group_by{|rec| rec['question_id']}.to_h
             @patient_responses = question_indexed_responses.map{|k,v| [k, v.size()]}
            
            @unique_tags  = @patient_responses.uniq{|rec| rec[0][0]}.collect{|rec| rec[0][0]}
           
            @images =  @patient_responses.select{|rec| rec[0][3] == 'image'}
           
            @image_urls = []
           
            if params[:refresh]!="hard_refresh" && Rails.cache.fetch([:images,"com.personicle.individual.datastreams.subjective.physician_questionnaire",session[:oktastate]['uid']])
                @image_urls = Rails.cache.fetch([:images,"com.personicle.individual.datastreams.subjective.physician_questionnaire",session[:oktastate]['uid']])
            else
                image_responses.each do |k,v|
                    v.each do |val|
                        image_keys = val['response'].split(";")
                            begin
                                image_keys.each do |key|
                                    res = JSON.parse(RestClient::Request.execute(:url => "https://personicle-file-upload.herokuapp.com/user_images/#{key}?user_id=#{params['data_for_user']}", headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                                    @image_urls.push([k, val['timestamp'], res['image_url']])
                            rescue => exception
                                if exception.response.code == 404
                                    next
                                end
                            end
                        end
                    end
                 end
                 @image_urls = @image_urls.group_by {|rec| rec[0]}.to_h

                 Rails.cache.write([:images,"com.personicle.individual.datastreams.subjective.physician_questionnaire",session[:oktastate]['uid']],@image_urls, expires_in: 12.minutes)
            end
            
            
            # @images.each do |i|
            #     image_keys = i[0][2].split(";")
            #     image_keys.each do |key|
            #         # image_keys_array.push(key)
            #      res = JSON.parse(RestClient::Request.execute(:url => "https://personicle-file-upload.herokuapp.com/user_images/#{key}?user_id=#{params['data_for_user']}", headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
            #      @image_urls.push(res['image_url'])
            #     end
            # end
   
        end

         if !@user_hr.empty?
            one_day_ago = @user_hr.select {|hr| hr['timestamp'] >= 1.day.ago}
           
            one_day_ago_max_hr =  !one_day_ago.empty? ? one_day_ago.max_by {|hr| hr['value']}.value : 0
            one_day_ago_min_hr = !one_day_ago.empty? ? one_day_ago.min_by {|hr| hr['value']}.value : 0
            
            last_two_weeks = @user_hr.select {|hr| hr['timestamp'] >= 2.weeks.ago}
            @last_two_weeks_max_hr = !last_two_weeks.empty? ? last_two_weeks.max_by {|hr| hr['value']}.value : 0
            @last_two_weeks_min_hr = !last_two_weeks.empty? ? last_two_weeks.min_by {|hr| hr['value']}.value : 0
            @avg_24_hour_hr = !one_day_ago.empty? ?  one_day_ago.sum {|hr| hr['value']}/one_day_ago.size : 0
     
        else
            @last_two_weeks_max_hr= 0
            @last_two_weeks_min_hr = 0
            @avg_24_hour_hr = 0
        end
        #step data
        if !@user_events.empty?
           
            daily_steps = @user_events.map {|event| {'date' => DateTime.parse(event['start_time']).to_date, 'value' => event['value']}}
            tmp = daily_steps.group_by {|rec| rec['date']}.to_h
            @daily_step_summary = tmp.map {|k,v| [k , v.sum {|r| r['value']}]}.to_h
            tmp2 = @daily_step_summary.group_by{|rec| rec[0].strftime('%Y-%U')}.to_h
            @weekly_step_summary = tmp2.map {|k,v| [k , v.sum {|r| r[1]}/ v.size]}.to_h

            tmp_steps = @user_events.select {|record| record['start_time'].to_datetime > 30.days.ago}.map {|rec| [rec['start_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
            @daily_steps = tmp_steps.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h
    
      
            @last_month_total_steps = @daily_steps.select {|k,v| k > 30.days.ago}.sum {|k,v| v}
            @last_month_steps_days = @daily_steps.select {|k,v| k > 30.days.ago}.size
            @last_week_total_steps = @daily_steps.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
            @last_week_steps_days = @daily_steps.select {|k,v| k > 7.days.ago}.size
      
            @last_week_average_steps = @last_week_steps_days>0? @last_week_total_steps/@last_week_steps_days:0
            @last_month_average_steps = @last_month_steps_days>0? @last_month_total_steps/@last_month_steps_days:0
        else
            @daily_step_summary = []
            @weekly_step_summary  = []
        end

        # calories data
        # puts "response calories"
        # puts @response_calories
        if !@response_calories.empty?
    
            tmp_calories = @response_calories.select {|record| record['end_time'].to_datetime > 30.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
            @daily_calories = tmp_calories.map {|k,v| [k, v.sum {|r| r[1]}]}.to_h
          
      
            @last_month_total_calories = @daily_calories.select {|k,v| k > 30.days.ago}.sum {|k,v| v}
           
            @last_month_calories_days = @daily_calories.select {|k,v| k > 30.days.ago}.size
      
            @last_week_total_calories = @daily_calories.select {|k,v| k > 7.days.ago}.sum {|k,v| v}
          
            @last_week_calories_days = @daily_calories.select {|k,v| k > 7.days.ago}.size
            
      
            @last_week_average_calories = @last_week_calories_days>0? @last_week_total_calories/@last_week_calories_days:0
           
            @last_month_average_calories = @last_month_calories_days>0? @last_month_total_calories/@last_month_calories_days:0
            # puts "last week calories"
            # puts @last_week_average_calories
            
            @response_calories_prev_week = @response_calories.select {|record| record['end_time'].to_datetime > 7.days.ago}.map {|rec| [rec['end_time'].to_date, rec['value']]}.group_by {|r| r[0]}.to_h
           
          end
        #sleep data 
        if !@user_data.empty?

            daily_sleep = @user_data.map {|event| {'date' => event['end_time'].to_datetime.to_date,'duration' => 24*(event['end_time'].to_datetime - event['start_time'].to_datetime).to_f}}
           
            tmp = daily_sleep.group_by {|rec| rec['date']}.to_h
            max_date = daily_sleep.map {|rec| rec['date']}.max
            min_date = daily_sleep.map {|rec| rec['date']}.min

            @daily_sleep_summary = tmp.map {|k,v| [k , v.sum {|r| r['duration']}]}.to_h
            (min_date..max_date).each do |d|
                if ! @daily_sleep_summary.key?(d)
                    @daily_sleep_summary[d]=0
                end 
            end
            @daily_sleep_summary = @daily_sleep_summary.sort.to_h
            tmp2 = daily_sleep.group_by {|rec| rec['date'].strftime('%Y-%U')}.to_h
            @weekly_sleep_summary = tmp2.map {|k,v| [k , v.sum {|r| r['duration']}/ v.size]}.to_h
            # moving_average_sleep = @daily_sleep_summary.each_cons(7).map {|recs| [recs.max {|r| r[0]}[0], recs.sum {|r| r[1]}/recs.sum {|r| (r[1] > 0)?1:0 }]}.to_h
            (min_date..max_date).each do |d|
                @daily_sleep_summary[d] = {'duration'=> @daily_sleep_summary[d], 'moving_average' => 0}
            end

            @sleep_events = @user_data.select {|event| event['event_name'] == 'Sleep'}
   
            @last_month_total_sleep = @sleep_events.select {|event| event['start_time'].to_datetime > 30.days.ago}.sum {|event| event['parameters']['duration']}/(60*1000)
            @last_month_sleep_event = @sleep_events.select {|event| event['start_time'].to_datetime > 30.days.ago}.size
            @last_week_total_sleep = @sleep_events.select {|event| event['start_time'].to_datetime > 7.days.ago}.sum {|event| event['parameters']['duration']}/(60*1000)
            @last_week_sleep_event = @sleep_events.select {|event| event['start_time'].to_datetime > 7.days.ago}.size
            
            @last_week_average_sleep = @last_week_sleep_event>0? @last_week_total_sleep/@last_week_sleep_event:0
            @last_month_average_sleep = @last_month_sleep_event>0? @last_month_total_sleep/@last_month_sleep_event:0
        else
            @daily_sleep_summary = []
            @weekly_sleep_summary  = []
        end

        respond_to do |format|
            format.html {render :index, locals: {unique_question_tags: @unique_tags, patient_responses: @patient_responses,avg_24_hour_hr: @avg_24_hour_hr,last_two_weeks_min_hr: @last_two_weeks_min_hr,last_two_weeks_max_hr: @last_two_weeks_max_hr,weekly_step_summary: @weekly_step_summary, daily_step_summary: @daily_step_summary, user_events: @user_events, daily_sleep_summary: @daily_sleep_summary, weekly_sleep_summary: @weekly_sleep_summary, user_data: @user_data, physician: @physician, user_id: params["data_for_user"]} }
        end
    end

    def create_account
    end

    def is_user_physician?
        if !session[:oktastate]["physician"]
            return redirect_to pages_dashboard_path
        end
    end
end