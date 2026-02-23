class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_parent
  before_action :authorize_comment!

  def create
    @comment = Comment.new(comment_params)
    @comment.webstead_id = Current.webstead.id
    @comment.parent = @parent

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

    # Whitelist allowed parent types to prevent RCE via constantize
    allowed_types = ["Post", "Comment"]

    if parent_type.in?(allowed_types) && parent_id.present?
      @parent = parent_type.constantize.find(parent_id)
    else
      redirect_to root_path, alert: "Invalid comment parent"
    end
  end

  def authorize_comment!
    unless @parent.webstead_id == Current.webstead.id
      redirect_to root_path, alert: "You can only comment on content from this webstead"
    end
  end

  def comment_params
    params.require(:comment).permit(:content, :parent_type, :parent_id, :actor_id, :actor_type)
  end
end
