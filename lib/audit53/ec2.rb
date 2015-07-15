require 'aws-sdk'
require 'contracts'

module Audit53
  module EC2
    include Contracts

    Contract ({ region: String }) => Aws::EC2::Client
    def self.client(region:)
      Aws::EC2::Client.new region: region
    end

    Contract ({ region: String }) => ArrayOf[Aws::EC2::Types::Instance]
    def self.instances(region:)
      client(region: region).describe_instances.each_page
        .flat_map(&:reservations)
        .flat_map(&:instances)
    end

    Contract None => Hash
    def self.ips
      @ips ||= %w(us-east-1 us-west-1 us-west-2 eu-west-1)
                     .flat_map { |r| instances region: r }
                     .map { |i| { i.public_ip_address => i.instance_id } }
                     .reduce({}, :update)
    end
  end
end
