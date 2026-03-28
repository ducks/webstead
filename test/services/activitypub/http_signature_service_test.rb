# frozen_string_literal: true

require "test_helper"

module ActivityPub
  class HttpSignatureServiceTest < ActiveSupport::TestCase
    setup do
      @keypair = OpenSSL::PKey::RSA.new(2048)
      @private_key_pem = @keypair.to_pem
      @public_key_pem = @keypair.public_key.to_pem
      @key_id = "https://example.com/actor#main-key"
    end

    test "signs a POST request with Date, Host, Digest, and Signature headers" do
      uri = URI.parse("https://remote.example/inbox")
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/activity+json"
      request.body = '{"type":"Create"}'

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      assert request["Date"].present?, "Date header missing"
      assert request["Host"].present?, "Host header missing"
      assert request["Digest"].present?, "Digest header missing"
      assert request["Signature"].present?, "Signature header missing"
    end

    test "Digest header contains SHA-256 hash of body" do
      uri = URI.parse("https://remote.example/inbox")
      body = '{"type":"Create","actor":"https://example.com/actor"}'
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = body

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      expected_digest = "SHA-256=#{Digest::SHA256.base64digest(body)}"
      assert_equal expected_digest, request["Digest"]
    end

    test "Signature header contains keyId, algorithm, headers, and signature" do
      uri = URI.parse("https://remote.example/inbox")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = '{"type":"Create"}'

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      sig_header = request["Signature"]
      assert_includes sig_header, "keyId=\"#{@key_id}\""
      assert_includes sig_header, 'algorithm="rsa-sha256"'
      assert_includes sig_header, 'headers="(request-target) host date digest"'
      assert_match(/signature="[A-Za-z0-9+\/=]+"/, sig_header)
    end

    test "signature can be verified with the corresponding public key" do
      uri = URI.parse("https://remote.example/inbox")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = '{"type":"Create"}'

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      # Parse the signature header
      sig_header = request["Signature"]
      sig_params = {}
      sig_header.scan(/(\w+)="([^"]*)"/).each { |k, v| sig_params[k] = v }

      headers_list = sig_params["headers"].split
      signing_string = headers_list.map do |header|
        case header
        when "(request-target)"
          "(request-target): post #{uri.request_uri}"
        else
          "#{header}: #{request[header]}"
        end
      end.join("\n")

      signature = Base64.strict_decode64(sig_params["signature"])
      public_key = OpenSSL::PKey::RSA.new(@public_key_pem)

      assert public_key.verify(OpenSSL::Digest::SHA256.new, signature, signing_string),
        "Signature verification failed"
    end

    test "GET requests do not include Digest header" do
      uri = URI.parse("https://remote.example/actor")
      request = Net::HTTP::Get.new(uri.request_uri)

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      assert_nil request["Digest"]
      assert request["Signature"].present?
      assert_includes request["Signature"], 'headers="(request-target) host date"'
    end

    test "Host header matches URI host" do
      uri = URI.parse("https://remote.example/inbox")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = "{}"

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      assert_equal "remote.example", request["Host"]
    end

    test "Date header is in HTTP date format" do
      uri = URI.parse("https://remote.example/inbox")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = "{}"

      HttpSignatureService.sign(request, uri, @key_id, @private_key_pem)

      # HTTP date format: "Thu, 01 Jan 2026 00:00:00 GMT"
      assert_nothing_raised { Time.httpdate(request["Date"]) }
    end
  end
end
