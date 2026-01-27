# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "openssl"

module ExifExplorer
  module Core
    module Geocoder
      USER_AGENT = "exif-explorer/#{ExifExplorer::VERSION} (https://github.com/anaice/exif-explorer)"

      module_function

      def reverse(lat, lng, provider: :nominatim)
        case provider
        when :nominatim
          NominatimGeocoder.reverse(lat, lng)
        when :none
          nil
        else
          raise GeocodingError, "Unknown geocoding provider: #{provider}"
        end
      end
    end

    class NominatimGeocoder
      BASE_URL = "https://nominatim.openstreetmap.org/reverse"

      def self.reverse(lat, lng)
        new.reverse(lat, lng)
      end

      def reverse(lat, lng)
        uri = URI(BASE_URL)
        uri.query = URI.encode_www_form(
          lat: lat,
          lon: lng,
          format: "json",
          addressdetails: 1,
          zoom: 18
        )

        response = fetch_with_retry(uri)
        parse_response(response)
      rescue StandardError => e
        raise GeocodingError, e.message
      end

      private

      def fetch_with_retry(uri, retries: 2)
        attempts = 0
        begin
          attempts += 1
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.open_timeout = 10
          http.read_timeout = 10

          # Use system CA certificates
          if File.exist?("/etc/ssl/certs/ca-certificates.crt")
            http.ca_file = "/etc/ssl/certs/ca-certificates.crt"
          elsif File.exist?("/etc/pki/tls/certs/ca-bundle.crt")
            http.ca_file = "/etc/pki/tls/certs/ca-bundle.crt"
          elsif File.exist?("/etc/ssl/cert.pem")
            http.ca_file = "/etc/ssl/cert.pem"
          end

          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = Geocoder::USER_AGENT
          request["Accept"] = "application/json"

          response = http.request(request)

          raise GeocodingError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          response.body
        rescue OpenSSL::SSL::SSLError
          # Retry without strict SSL verification as fallback
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          response = http.request(request)
          raise GeocodingError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
          response.body
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
          if attempts <= retries
            sleep(1)
            retry
          end
          raise GeocodingError, "Connection failed: #{e.message}"
        end
      end

      def parse_response(body)
        data = JSON.parse(body)

        return nil if data["error"]

        address = data["address"] || {}

        {
          street: address["road"] || address["pedestrian"] || address["footway"],
          number: address["house_number"],
          neighborhood: address["suburb"] || address["neighbourhood"] || address["district"],
          city: address["city"] || address["town"] || address["village"] || address["municipality"],
          state: address["state"],
          country: address["country"],
          postcode: address["postcode"],
          display_name: data["display_name"]
        }
      end
    end
  end
end
