class PostsController < ApplicationController
  include TenantScoped

  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_post, only: [ :show, :edit, :update ]
  before_action :authorize_post_owner!, only: [ :edit, :update ]

  def index
    @posts = Current.webstead.posts.published.recent

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @post = Current.webstead.posts.build
  end

  def create
    @post = Current.webstead.posts.build(post_params)
    # TODO: Set user when authentication is implemented (step 17)
    # @post.user = current_user

    if @post.save
      redirect_to @post, notice: "Post was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = Current.webstead.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :published_at)
  end

  # TODO: Replace with Rails 8 authentication (step 17)
  def authenticate_user!
    head :unauthorized unless current_user
  end

  # TODO: Replace with Rails 8 authentication (step 17)
  def current_user
    @current_user ||= nil # Will be: User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  def authorize_post_owner!
    return unless current_user # Skip if no auth yet
    head :forbidden unless @post.user == current_user
  end
end
