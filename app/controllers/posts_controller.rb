class PostsController < ApplicationController
  include TenantScoped

  before_action :authenticate_user!, only: [ :new, :create, :edit, :update ]
  before_action :set_post, only: [ :show, :edit, :update ]
  before_action :authorize_post_owner!, only: [ :edit, :update ]

  def index
    @posts = Current.webstead.posts.published.recent
  end

  def show
    @comments = @post.comments.root_comments.chronological
  end

  def new
    @post = Current.webstead.posts.build
  end

  def create
    @post = Current.webstead.posts.build(post_params)
    @post.user = current_user if current_user

    if @post.save
      redirect_to post_path(@post), notice: "Post was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to post_path(@post), notice: "Post was successfully updated."
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

  def authorize_post_owner!
    return if !current_user # Skip authorization if no auth yet
    head :forbidden if !(@post.user == current_user)
  end
end
