require 'fastlane/action'
require 'fastlane_core'
require_relative '../helper/firebase_app_distribution_apis'
require_relative '../helper/firebase_app_distribution_auth_client'
require_relative '../helper/firebase_app_distribution_error_message'
require_relative '../helper/firebase_app_distribution_helper'

module Fastlane
  module Actions
    module SharedValues
      FIREBASE_APP_DISTRO_BUILD_NAME_COUNT ||= :FIREBASE_APP_DISTRO_BUILD_NAME_COUNT
    end

    class FirebaseAppDistributionGetBuildNameAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        init_google_api_client(params[:debug])
        client = Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService.new
        client.authorization = get_authorization(params[:service_credentials_file], params[:firebase_cli_token], params[:service_credentials_json_data], params[:debug])

        app_id = app_id_from_params(params)
        build_name = params[:build_name]

        UI.user_error!("You must provide a build_name") if build_name.nil? || build_name.strip.empty?

        UI.message("⏳ Counting releases with buildName=#{build_name} for app #{app_id}...")

        count = count_releases_by_build_name(client, app_id, build_name)

        UI.success("✅ Found #{count} releases with buildName=#{build_name}.")
        Actions.lane_context[SharedValues::FIREBASE_APP_DISTRO_BUILD_NAME_COUNT] = count
        return count
      end

      def self.count_releases_by_build_name(client, app_id, build_name)
        parent = app_name_from_app_id(app_id)
        all_releases = []
        next_page_token = nil

        begin
          response = client.list_project_app_releases(parent, page_size: 100, page_token: next_page_token)
          all_releases.concat(response.releases) if response.releases
          next_page_token = response.next_page_token
        end while next_page_token

        matching_releases = all_releases.select { |release| release.build_name == build_name }
        matching_releases.count
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Counts the number of releases in Firebase App Distribution matching a specific buildName"
      end

      def self.details
        [
          "Fetches all releases in App Distribution and counts how many have the specified buildName."
        ].join("\n")
      end

      def self.available_options
        [
          # iOS Specific
          FastlaneCore::ConfigItem.new(key: :googleservice_info_plist_path,
                                       env_name: "GOOGLESERVICE_INFO_PLIST_PATH",
                                       description: "Path to your GoogleService-Info.plist file, relative to the archived product path (or directly, if no archived product path is found)",
                                       default_value: "GoogleService-Info.plist",
                                       optional: true,
                                       type: String),

          # General
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "FIREBASEAPPDISTRO_APP",
                                       description: "Your app's Firebase App ID. You can find the App ID in the Firebase console, on the General Settings page",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :firebase_cli_token,
                                       description: "Auth token generated using Firebase CLI's login:ci command",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :service_credentials_file,
                                       description: "Path to Google service account json",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :service_credentials_json_data,
                                       description: "Google service account json file content",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :debug,
                                       description: "Print verbose debug output",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :build_name,
                                       description: "The buildName to count releases for",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.output
        [
          ['FIREBASE_APP_DISTRO_BUILD_NAME_COUNT', 'The number of releases matching the specified buildName']
        ]
      end

      def self.return_value
        "The number of releases matching the provided buildName."
      end

      def self.return_type
        :int
      end

      def self.authors
        ["lkellogg@google.com", "modified_by_you"]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'count = firebase_app_distribution_get_latest_release(
            app: "<your Firebase app ID>",
            build_name: "10"
          )',
          'puts "Number of releases with buildName 10: #{count}"'
        ]
      end

      def self.sample_return_value
        3
      end
    end
  end
end