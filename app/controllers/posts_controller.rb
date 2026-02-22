class PostsController < ApplicationController
  before_action :set_post, only: [:show]

  def index
    @posts = Current.webstead.posts.published.recent

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @comments = @post.comments.root_level.recent.includes(:user, :federated_actor, :replies)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def set_post
    @post = Current.webstead.posts.published.find(params[:id])
  end
end
