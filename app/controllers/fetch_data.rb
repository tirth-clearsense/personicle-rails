class FetchData

    def self.get_events(ses=session,event=event_type,is_hard_refresh=refresh)
        three_months_ago = 3.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
        current_time = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")
        url = ENV['EVENTS_ENDPOINT']+"?startTime="+three_months_ago+"&endTime="+current_time
        
        if !is_hard_refresh # if reload is not hard refresh
            if event # if event type is specified
                if Rails.cache.fetch([:events,ses[:oktastate]['uid'],"all_events"]) # and all events for this user are in the cache 
                    Rails.cache.fetch([:events,ses[:oktastate]['uid'],"all_events"]).select {|e| e['event_name'] == event} # then select the event specified in parameter
                else # get event by making api call
                    url = ENV['EVENTS_ENDPOINT']+"?startTime="+three_months_ago+"&endTime="+current_time+"&event_type="+event
                    JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                end
            else # no event is specifed
                Rails.cache.fetch([:events,ses[:oktastate]['uid'],"all_events"], expires_in: 20.minutes) do # check the cache for all events, if expired/nil make api call 
                    JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
                end
            end
        else # if hard refresh, make api call to get all events
            JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
        end
    end

    def self.get_datastreams(ses=session,data_source=source, datatype=data_type,is_hard_refresh=refresh)
        start_date = 3.months.ago.strftime("%Y-%m-%d %H:%M:%S.%6N")
        end_date = Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")
        url = ENV['DATASTREAMS_ENDPOINT']+"?startTime="+start_date+"&endTime="+end_date+"&source="+data_source+"&datatype="+datatype
        if !is_hard_refresh
            Rails.cache.fetch([:datastreams,ses[:oktastate]['uid']], expires_in: 20.minutes) do
                JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
            end
        else
            JSON.parse(RestClient::Request.execute(:url => url, headers: {Authorization: "Bearer #{ses[:oktastate]['credentials']['token']} "}, :method => :get,:verify_ssl => false ),object_class: OpenStruct)
        end

    end
end