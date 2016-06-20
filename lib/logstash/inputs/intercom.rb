# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/timestamp"
require "logstash/util"
require "intercom"

# This plugin was created as a way to ingest data from Intercom into Logstash.
#
# ==== Usage:
#
# Here is an example of setting up the plugin to fetch data from Intercom.
#
# [source,ruby]
# ----------------------------------
# input {
#   intercom {
#     app_id => ":appId"
#     api_key => ":appApiKey"
#   }
# }
# ----------------------------------
#
class LogStash::Inputs::Intercom < LogStash::Inputs::Base
  config_name "intercom"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  # Application ID
  config :app_id, :validate => :string

  # Application API Key
  config :app_api_key, :validate => :string

  # Set if we want to synchronize events
  config :sync_events, :validate => :boolean, :default => true

  public

  def register
    configure_intercom_client
  end # def register

  def run(queue)
    sync_all(queue)
  end # def run

  def stop
  end

  private

  def configure_intercom_client
    Intercom.app_id = @app_id
    Intercom.app_api_key = @app_api_key
  end

  def sync_all(queue)
    if @sync_events
      sync_events queue
    end
  end

  def sync_events(queue)
    begin
      get_users.each { |user| sync_events_for queue, user.id }
    rescue Intercom::IntercomError => error
      @logger.error? @logger.error("Failed to sync events", :error => error.to_s)
    end
  end

  def sync_events_for(queue, intercom_user_id)
    begin
      get_events(intercom_user_id).each { |event| push_event queue, from_event(event) }
    rescue Intercom::IntercomError => error
      @logger.error? @logger.error("Failed to sync events for user", :intercom_user_id => intercom_user_id, :error => error.to_s)
    end
  end

  def get_users
    Intercom::User.all
  end

  def get_events(intercom_user_id)
    Intercom::Event.find_all(:type => 'user', :intercom_user_id => intercom_user_id)
  end

  def from_event(intercom_event)
    hash = prefix_keys flatten_hash(intercom_event.to_hash), 'event_'
    hash['document_id'] = 'event_' + intercom_event.id
    hash['type'] = 'event'

    event = LogStash::Event.new(LogStash::Util.stringify_symbols(hash))
    event.timestamp = LogStash::Timestamp.new(intercom_event.created_at)
    event
  end

  def prefix_keys(hash, prefix)
    hash.each_with_object({}) do |(k, v), h|
      if k.start_with? prefix
        h[k] = v
      else
        h["#{prefix}#{k}"] = v
      end
    end
  end

  def flatten_hash(hash)
    hash.each_with_object({}) do |(k, v), h|
      if v.is_a? Hash
        flatten_hash(v).map do |h_k, h_v|
          h["#{k}_#{h_k}"] = h_v
        end
      else
        h[k] = v
      end
    end
  end

  def push_event(queue, event)
    decorate(event)
    queue << event
  end

end # class LogStash::Inputs::Intercom
