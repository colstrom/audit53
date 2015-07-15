require 'aws-sdk'
require 'contracts'

module Audit53
  module Route53
    include Contracts

    Contract Maybe[({ region: String })] => Aws::Route53::Client
    def self.client(region: 'us-west-1')
      @client ||= Aws::Route53::Client.new region: region
    end

    Contract ({ domain: String }) => String
    def self.zone_id(domain:)
      domain += '.' unless domain.end_with? '.'
      @zone_id ||= client.list_hosted_zones
                   .hosted_zones
                   .select { |z| z.name == domain }
                   .map { |z| z.id.split('/').last }
                   .reduce
    end

    Contract ({ zone_id: String }) => ArrayOf[Aws::Route53::Types::ResourceRecordSet]
    def self.records(zone_id:)
      @records ||= client.list_resource_record_sets(hosted_zone_id: zone_id)
                   .each_page
                   .flat_map(&:resource_record_sets)
                   .reject(&:alias_target)
    end

    Contract ({ zone_id: String, type: String }) => Hash
    def self.records_subset(zone_id:, type:)
      records(zone_id: zone_id)
        .select { |r| r.type == type }
        .map { |r| { r.resource_records.first.value => r.name } }
        .reduce({}, :update)
    end

    Contract ({ zone_id: String }) => Hash
    def self.cname_ips(zone_id:)
      records_subset(zone_id: zone_id, type: 'CNAME')
        .select { |k, _| k.start_with? 'ec2' }
        .map { |k, v| { k.split('.').first.split('-').last(4).join('.') => v } }
        .reduce({}, :update)
    end

    Contract ({ zone_id: String }) => Hash
    def self.ips(zone_id:)
      records_subset(zone_id: zone_id, type: 'A"').merge cname_ips(zone_id: zone_id)
    end
  end
end
