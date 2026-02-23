class WebsteadsController < ApplicationController
  before_action :authenticate_user!, only: [ :dashboard ]

  def new
    @user = User.new
    @webstead = Webstead.new
  end

  def create
    ActiveRecord::Base.transaction do
      @user = User.new(user_params)
      @webstead = Webstead.new(webstead_params)

      if @user.save && @webstead.update(user: @user)
        session[:user_id] = @user.id
        redirect_to provisioning_webstead_path(@webstead), notice: "Welcome to Webstead!"
      else
        @user.errors.full_messages.each { |msg| @webstead.errors.add(:base, "User: #{msg}") }
        render :new, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def check_availability
    subdomain = params[:subdomain].to_s.strip.downcase

    if subdomain.blank?
      render json: { available: false, message: "Subdomain cannot be blank" }
      return
    end

    if subdomain.length < 3 || subdomain.length > 63
      render json: { available: false, message: "Subdomain must be between 3 and 63 characters" }
      return
    end

    if !subdomain.match?(/\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/)
      render json: { available: false, message: "Invalid subdomain format" }
      return
    end

    if Webstead::RESERVED_SUBDOMAINS.include?(subdomain)
      render json: { available: false, message: "#{subdomain} is a reserved subdomain" }
      return
    end

    if Webstead.exists?(subdomain: subdomain)
      render json: { available: false, message: "#{subdomain}.webstead.dev is already taken" }
      return
    end

    render json: { available: true, message: "#{subdomain}.webstead.dev is available!" }
  end

  def dashboard
    @webstead = current_user.webstead
    if @webstead.nil?
      redirect_to new_webstead_path, alert: "You need to create a webstead first"
    end
  end

  def provisioning
    @webstead = Webstead.find(params[:id])
    if @webstead.user != current_user
      redirect_to root_path, alert: "Access denied"
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :username, :password, :password_confirmation)
  end

  def webstead_params
    params.require(:webstead).permit(:subdomain)
  end
end
