# frozen_string_literal: true

module ActivityPub
  # Service for signing HTTP requests using HTTP Signatures (draft-cavage-http-signatures)
  # https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures
  class HttpSignatureService
    def self.sign(request, uri, key_id, private_key_pem)
      new(key_id, private_key_pem).sign(request, uri)
    end

    def initialize(key_id, private_key_pem)
      @key_id = key_id
      @private_key_pem = private_key_pem
    end

    def sign(request, uri)
      # Add required headers
      request["Date"] = Time.now.utc.httpdate
      request["Host"] = uri.host

      # Add Digest header for POST requests
      if request.is_a?(Net::HTTP::Post)
        body = request.body || ""
        digest = Digest::SHA256.base64digest(body)
        request["Digest"] = "SHA-256=#{digest}"
      end

      # Build headers list for signature
      headers = [ "(request-target)", "host", "date" ]
      headers << "digest" if request["Digest"].present?

      # Build signing string
      signing_string = headers.map do |header|
        case header
        when "(request-target)"
          "(request-target): #{request.method.downcase} #{uri.request_uri}"
        else
          "#{header}: #{request[header]}"
        end
      end.join("\n")

      # Sign with private key
      private_key = OpenSSL::PKey::RSA.new(@private_key_pem)
      signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_string)
      signature_base64 = Base64.strict_encode64(signature)

      # Add Signature header
      request["Signature"] = "keyId=\"#{@key_id}\",algorithm=\"rsa-sha256\",headers=\"#{headers.join(' ')}\",signature=\"#{signature_base64}\""
    end
  end
end
