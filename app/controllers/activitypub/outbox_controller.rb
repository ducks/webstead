module ActivityPub
  class OutboxController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_webstead

    def show
      posts = @webstead.posts.published.order(published_at: :desc)
      total_items = posts.count

      if params[:page].present?
        render_page(posts, total_items)
      else
        render_collection(total_items)
      end
    end

    private

    def set_webstead
      @webstead = Webstead.find_by(subdomain: params[:username])
      return head :not_found unless @webstead
    end

    def render_collection(total_items)
      render json: {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: outbox_url,
        type: 'OrderedCollection',
        totalItems: total_items,
        first: page_url(1),
        last: page_url(last_page_number(total_items))
      }, content_type: 'application/activity+json'
    end

    def render_page(posts, total_items)
      page_number = params[:page].to_i
      page_number = 1 if page_number < 1

      paginated_posts = posts.limit(30).offset((page_number - 1) * 30)
      last_page = last_page_number(total_items)

      response = {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: page_url(page_number),
        type: 'OrderedCollectionPage',
        partOf: outbox_url,
        orderedItems: paginated_posts.map { |post| create_activity(post) }
      }

      response[:next] = page_url(page_number + 1) if page_number < last_page
      response[:prev] = page_url(page_number - 1) if page_number > 1

      render json: response, content_type: 'application/activity+json'
    end

    def create_activity(post)
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: "#{post_url(post)}#activity",
        type: 'Create',
        actor: actor_url,
        published: post.published_at.iso8601,
        to: ['https://www.w3.org/ns/activitystreams#Public'],
        cc: ["#{actor_url}/followers"],
        object: note_object(post)
      }
    end

    def note_object(post)
      {
        id: post_url(post),
        type: 'Note',
        attributedTo: actor_url,
        content: Kramdown::Document.new(post.body).to_html,
        published: post.published_at.iso8601,
        url: post_url(post),
        tag: []
      }
    end

    def outbox_url
      "https://#{@webstead.primary_domain}/@#{@webstead.subdomain}/outbox"
    end

    def page_url(page_number)
      "#{outbox_url}?page=#{page_number}"
    end

    def actor_url
      "https://#{@webstead.primary_domain}/actor"
    end

    def post_url(post)
      "https://#{@webstead.primary_domain}/posts/#{post.id}"
    end

    def last_page_number(total_items)
      return 1 if total_items.zero?
      ((total_items - 1) / 30) + 1
    end
  end
end
