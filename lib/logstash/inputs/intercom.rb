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
#     app_api_key => ":appApiKey"
#     sync_users => true
#     sync_events => true
#     flatten_excludes => []
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

  #Set if we want to synchronize users
  config :sync_users, :validate => :boolean, :default => true

  # Set a list of keys to not flatten during export
  config :flatten_excludes, :validate => :array, :default => []

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
    sync_users queue if @sync_users
    sync_events queue if @sync_events
  end

  def sync_users(queue)
    begin
      get_users.each { |user| push_event queue, from_user(user) }
    rescue Intercom::IntercomError => error
      @logger.error? @logger.error("Failed to sync users", :error => error.to_s)
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

  def from_user(intercom_user)
    hash = intercom_object_to_hash intercom_user, 'user'
    hash_to_logstash_event hash, intercom_user.created_at
  end

  def from_event(intercom_event)
    hash = intercom_object_to_hash intercom_event, 'event'
    hash_to_logstash_event hash, intercom_event.created_at
  end

  def hash_to_logstash_event(hash, timestamp)
    event = LogStash::Event.new LogStash::Util.stringify_symbols(hash)
    event.timestamp = LogStash::Timestamp.new timestamp
    event
  end

  def intercom_object_to_hash(intercom_object, type)
    # flatten object
    hash = flatten_hash intercom_object.to_hash

    # prefix all keys by the object type (avoid collision between fields names)
    hash = prefix_keys hash, "#{type}_"

    # adds identity
    hash['type'] = type
    hash['document_id'] = "#{type}_#{intercom_object.id}"

    hash
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
      if v.respond_to? :to_hash and not @flatten_excludes.include? k
        flatten_hash(v.to_hash).map do |h_k, h_v|
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
