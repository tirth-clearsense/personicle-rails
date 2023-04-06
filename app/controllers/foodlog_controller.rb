class FoodlogController < ApplicationController
    require 'json'
    require 'ostruct'
    require 'date'
    before_action :require_user, :session_active?, :get_user_notifications
    
    def index
        if !params[:noti_id].nil? &&  !params[:noti_id].blank? 
            @notification_read = Notification.find_by(id: params[:noti_id]).mark_as_read!
        end
        
    end
    
    def get_edamam_data
    @notifications = UserNotification.get_notifications(session[:oktastate]['uid'])

        required = [:q, :mealType, :cuisineType]
      
        form_complete = true
        required.each do |k|
            if params.has_key?(k) and not params[k].blank?
            else
                form_complete = false
            end
        end
        if form_complete
            form_status_msg = 'Fetching recipes!'
            url = "https://api.edamam.com/search?q=#{params[:q]}&mealType=#{params[:mealType]}&cuisinetype=#{params[:cuisineType]}&app_id=0254fb82&app_key=4856fb6baec97ae4ba40af3dc73edef8&to=100"
            res = RestClient::Request.execute(:url => url, :method => :get)
            response = JSON.parse(res,object_class: OpenStruct)
            
          else
            form_status_msg = 'Please fill out all fields'
        end
       
        if form_complete
            if response.count == 0
                respond_to do |format|
                    format.html {render :index, locals: { feedback: params, recipes: response.hits, count: response.count } }
                    # redirect_to pages_recipes_path, recipes: response.hits
                end
            else
                respond_to do |format|
                    format.html {render :recipes, locals: { status_msg: form_status_msg, feedback: params, recipes: response.hits, count: response.count } }
                  
                end
            end
            
        else 
            respond_to do |format|
                format.html {render :index, locals: { status_msg: form_status_msg, feedback: params, count: response.count } }
            end
        end
        
    end

    def log_food
        
        if  not params[:start_time].blank?
            start_time = params[:start_date]+" "+ params[:start_time] + ":00"

        else
            start_time = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")
        end
        
        if  not params[:start_time].blank?
            end_time = params[:start_date]+" "+ params[:end_time] + ":00"
        else
            default_end_time = Time.now.utc + 15.minutes
            end_time = default_end_time.strftime("%Y-%m-%d %H:%M:%S.%6N")
        end
       
        start_time_millis = (Time.parse(start_time).to_f)*1000
        end_time_millis = (Time.parse(end_time).to_f)*1000
        duration = end_time_millis - start_time_millis
        # puts params[:ingredients]
        # puts start_time.class
        # puts end_time.class
        # puts Time.find_zone("UTC").parse(end_time)
        data = [{
            "individual_id": "#{session[:oktastate]["uid"]}",
            "start_time": "#{Time.find_zone("UTC").parse(start_time)}",
            "end_time": "#{Time.find_zone("UTC").parse(end_time)}",
            "duration": "#{duration}",
            "event_name": "Food",
            "event_type": "org.personicle.individual.event.food"
            "source": "personicle-foodlogger",
            "parameters": "{\"recipe_name\": \"#{params[:recipe_name]}\", \"duration\": \"#{duration}\", \"servings\" : \"#{params[:servings]}\" , \"ingredients\": \"#{params[:ingredients]}\"}"
        }]
      
        res = RestClient::Request.execute(:url => ENV['EVENT_UPLOAD'], :payload => data.to_json, :method => :post, headers: {Authorization: "Bearer #{session[:oktastate]['credentials']['token']}", content_type: :json})
        # puts res
        # puts data.to_json
        if res
            respond_to do |format|
                format.html {render :index, locals: { status_msg: "Successfully logged your meal"} }
            end
        end

    end
  end
  