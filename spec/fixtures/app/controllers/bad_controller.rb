class BadController < ApplicationController
  API_SECRET = "sk_live_1234567890"

  def index
    @users = User.count
    @posts = Post.count
    @comments = Comment.count
    @tags = Tag.where("created_at >= ?", 1.week.ago)

    @avg = if @users > 0
      (@posts.to_f / @users).round(2)
    else
      0
    end

    @latest = Post.last&.comments&.last&.user&.name

    @growth = []
    6.downto(0) do |i|
      week_start = i.weeks.ago.beginning_of_week
      week_end = i.weeks.ago.end_of_week
      count = User.where(created_at: week_start..week_end).count
      @growth << { week: week_start.strftime("%b %d"), count: count }
    end

    @search = params[:q]
    @results = User.where("name LIKE ?", "%#{@search}%")
                   .order(Arel.sql("LENGTH(name) DESC"))

    respond_to do |format|
      format.html
      format.json { render json: @user }
    end
  end

  def create
    body = params.dig(:item, :body)
    begin
      cleaned = body.strip
    rescue
    end
  end
end
