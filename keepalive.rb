#!/usr/local/rvm/wrappers/default/ruby
#
# Sensu Handler: keepalive
#
# This handler receives a keepalive notification, alerts once by email and
# creates a stash until the keepalive is resolved.

require 'sensu-plugin'
require 'sensu-handler'
require 'mail'
require 'timeout'

class Keepalive < Sensu::Handler
  def status
    codes = Sensu::Plugin::EXIT_CODES.invert

    codes[@event['check']['status']]
  end

  # Override filter so we can handle events even when silenced
  def filter
    filter_disabled
    filter_repeated
    # filter_silenced
    filter_dependencies
  end

  def filter_repeated
    return if @event['occurrences'] <= 1 || @event['action'] != 'create'

    bail 'only handling the first occurrence of a keepalive alert'
  end

  def handle
    if status == 'OK'
      remove_stash
    elsif status == 'CRITICAL'
      create_stash
      notify_failure
    end
  end

  def client
    @event['client']['name']
  end

  def create_stash
    api_request(:POST, "/stashes/silence/#{client}") do |req|
      req.body = {
        message: 'Keepalive Failed'
      }.to_json
    end
  end

  def remove_stash
    api_request(:DELETE, "/stashes/silence/#{client}")
  end

  def mail_body
<<-BODY
#{client} has not reported to Sensu recently.

Other checks regarding this host have been silenced.
They will be unsilenced when it reports again.
BODY
  end

  def notify_failure
    mail_to = settings['keepalive-handler']['mail_to']
    mail_from = settings['keepalive-handler']['mail_from']
    subject = "#{client} has gone away"
    body = mail_body

    Mail.defaults do
      delivery_method :sendmail
    end

    Mail.deliver do
      to mail_to
      from mail_from
      subject subject
      body body
    end
  end
end
