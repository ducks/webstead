class CommentsController < ApplicationController
  include ActionView::RecordIdentifier
  include TenantScoped

  before_action :authenticate_user!
  before_action :set_parent
  before_action :authorize_comment!

  def create
    @comment = Comment.new(comment_params)
    @comment.webstead = Current.webstead
    @comment.user = current_user

    if @parent.is_a?(Post)
      @comment.post = @parent
    elsif @parent.is_a?(Comment)
      @comment.post = @parent.post
      @comment.parent = @parent
    end

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back(fallback_location: root_path, notice: "Comment posted successfully.") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("comment_form_#{dom_id(@parent)}", partial: "comments/form", locals: { parent: @parent, comment: @comment }) }
        format.html { redirect_back(fallback_location: root_path, alert: "Failed to post comment: #{@comment.errors.full_messages.join(', ')}") }
      end
    end
  end

  private

  def set_parent
    parent_type = params[:comment][:parent_type]
    parent_id = params[:comment][:parent_id]

    klass = case parent_type
    when "Post" then Post
    when "Comment" then Comment
    else nil
    end

    if klass && parent_id.present?
      @parent = klass.find(parent_id)
    else
      redirect_to root_path, alert: "Invalid comment parent"
    end
  end

  def authorize_comment!
    return if @parent.nil?

    webstead_id = @parent.webstead_id
    if !Current.webstead || webstead_id != Current.webstead.id
      redirect_to root_path, alert: "You can only comment on content from this webstead"
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
