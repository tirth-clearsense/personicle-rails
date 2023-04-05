class FetchData

    def self.get_events(ses=session,event=event_type,start_time=st,end_time=et,is_hard_refresh=hard_refresh, user_id)
       
        url = ENV['EVENTS_ENDPOINT']+"?startTime="+start_time+"&endTime="+end_time+"&user_id="+user_id
        
        if !is_hard_refresh # if reload is not hard refresh
            if event # if event type is specified
               
                if Rails.cache.fetch([:events,user_id,"all_events"]) # and all events for this user are in the cache 
                    Rails.cache.fetch([:events,user_id,"all_events"]).select {|e| e['event_name'] == event} # then select the event specified in parameter
                elsif Rails.cache.fetch([:events,user_id,event])# look for particular event in cache
                    Rails.cache.fetch([:events,user_id,event]).select {|e| e['event_name'] == event}
                else
                    url = ENV['EVENTS_ENDPOINT']+"?startTime="+start_time+"&endTime="+end_time+"&event_type="+event+"&user_id="+user_id
                    res = JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                    Rails.cache.write([:events,user_id,event],res, expires_in: 20.minutes)
                    res
                end
            else # no event is specifed
                Rails.cache.fetch([:events,user_id,"all_events"], expires_in: 20.minutes) do # check the cache for all events, if expired/nil make api call 
                    JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                end
            end
        else # if hard refresh, make api call to get all events
            if event
                url = ENV['EVENTS_ENDPOINT']+"?startTime="+start_time+"&endTime="+end_time+"&event_type="+event+"&user_id="+user_id
                res = JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                Rails.cache.write([:events,user_id,event],res, expires_in: 20.minutes)
                res
            else
                res = JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                Rails.cache.write([:events,user_id,"all_events"],res, expires_in: 20.minutes)
                res
            end
        end
    end

    def self.get_datastreams(ses=session,data_source=source, datatype=data_type,start_date=st, end_date=et, is_hard_refresh=hard_refresh, user_id=uid)
        if data_source.nil?
            
            url = ENV['DATASTREAMS_ENDPOINT']+"?startTime="+start_date+"&endTime="+end_date+"&datatype="+datatype+"&user_id="+user_id
        else
            url = ENV['DATASTREAMS_ENDPOINT']+"?startTime="+start_date+"&endTime="+end_date+"&source="+data_source+"&datatype="+datatype+"&user_id="+user_id
        end
        
            if !is_hard_refresh
                Rails.cache.fetch([:datastreams,datatype,user_id], expires_in: 20.minutes) do
                    JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                end
            else
                res = JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                Rails.cache.write([:datastreams,datatype,user_id],res, expires_in: 20.minutes)
                res
            end

    end
end