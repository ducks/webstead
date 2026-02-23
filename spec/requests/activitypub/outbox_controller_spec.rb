require 'rails_helper'

RSpec.describe ActivityPub::OutboxController, type: :request do
  let(:user) { User.create!(email: 'test@example.com', username: 'testuser', password: 'password123') }
  let(:webstead) { Webstead.create!(subdomain: 'alice', user: user) }

  describe 'GET /@:username/outbox' do
    context 'when webstead does not exist' do
      it 'returns 404' do
        get '/@nonexistent/outbox', headers: { 'Accept' => 'application/activity+json' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when webstead exists with no posts' do
      before { webstead }

      it 'returns OrderedCollection with zero items' do
        get '/@alice/outbox', headers: { 'Accept' => 'application/activity+json' }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/activity+json; charset=utf-8')

        json = JSON.parse(response.body)
        expect(json['@context']).to eq('https://www.w3.org/ns/activitystreams')
        expect(json['type']).to eq('OrderedCollection')
        expect(json['totalItems']).to eq(0)
        expect(json['id']).to eq("https://#{webstead.primary_domain}/@alice/outbox")
      end
    end

    context 'when webstead has published posts' do
      let!(:post1) { Post.create!(webstead: webstead, title: 'First Post', body: 'Content 1', status: 'published', published_at: 2.days.ago) }
      let!(:post2) { Post.create!(webstead: webstead, title: 'Second Post', body: 'Content 2', status: 'published', published_at: 1.day.ago) }
      let!(:draft_post) { Post.create!(webstead: webstead, title: 'Draft', body: 'Draft content', status: 'draft') }

      it 'returns OrderedCollection without page parameter' do
        get '/@alice/outbox', headers: { 'Accept' => 'application/activity+json' }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['type']).to eq('OrderedCollection')
        expect(json['totalItems']).to eq(2)
        expect(json['first']).to include('page=1')
        expect(json['last']).to include('page=1')
      end

      it 'returns OrderedCollectionPage with page parameter' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['type']).to eq('OrderedCollectionPage')
        expect(json['partOf']).to eq("https://#{webstead.primary_domain}/@alice/outbox")
        expect(json['orderedItems'].length).to eq(2)
      end

      it 'orders posts by published_at DESC' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        first_item = json['orderedItems'].first
        expect(first_item['object']['content']).to include('Content 2')
      end

      it 'does not include draft posts' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        items = json['orderedItems']
        expect(items.length).to eq(2)
        expect(items.any? { |item| item['object']['content'].include?('Draft') }).to be false
      end

      it 'includes proper Create activity structure' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        activity = json['orderedItems'].first
        expect(activity['@context']).to eq('https://www.w3.org/ns/activitystreams')
        expect(activity['type']).to eq('Create')
        expect(activity['actor']).to eq("https://#{webstead.primary_domain}/actor")
        expect(activity['to']).to include('https://www.w3.org/ns/activitystreams#Public')
        expect(activity['object']['type']).to eq('Note')
      end

      it 'includes proper Note object structure' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        note = json['orderedItems'].first['object']
        expect(note['type']).to eq('Note')
        expect(note['attributedTo']).to eq("https://#{webstead.primary_domain}/actor")
        expect(note['content']).to be_present
        expect(note['published']).to be_present
        expect(note['url']).to include("/posts/")
        expect(note['tag']).to eq([])
      end

      it 'renders markdown content as HTML' do
        post_with_markdown = Post.create!(
          webstead: webstead,
          title: 'Markdown Post',
          body: '# Heading\n\n**Bold text**',
          status: 'published',
          published_at: Time.current
        )

        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        markdown_note = json['orderedItems'].find { |item| item['object']['url'].include?(post_with_markdown.id.to_s) }
        expect(markdown_note['object']['content']).to include('<h1>Heading</h1>')
        expect(markdown_note['object']['content']).to include('<strong>Bold text</strong>')
      end
    end

    context 'pagination with many posts' do
      before do
        webstead
        35.times do |i|
          Post.create!(
            webstead: webstead,
            title: "Post #{i}",
            body: "Content #{i}",
            status: 'published',
            published_at: (35 - i).days.ago
          )
        end
      end

      it 'limits to 30 items per page' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        expect(json['orderedItems'].length).to eq(30)
      end

      it 'includes next link on first page' do
        get '/@alice/outbox?page=1', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        expect(json['next']).to include('page=2')
        expect(json['prev']).to be_nil
      end

      it 'includes prev and next links on middle page' do
        get '/@alice/outbox?page=2', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        expect(json['prev']).to include('page=1')
        expect(json['next']).to be_nil
      end

      it 'returns remaining items on last page' do
        get '/@alice/outbox?page=2', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        expect(json['orderedItems'].length).to eq(5)
        expect(json['next']).to be_nil
      end

      it 'calculates correct last page number' do
        get '/@alice/outbox', headers: { 'Accept' => 'application/activity+json' }
        json = JSON.parse(response.body)

        expect(json['totalItems']).to eq(35)
        expect(json['last']).to include('page=2')
      end
    end
  end
end
