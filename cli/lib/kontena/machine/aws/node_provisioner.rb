require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'
require_relative 'common'

module Kontena
  module Machine
    module Aws
      class NodeProvisioner
        include RandomName
        include Common

        attr_reader :ec2, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(api_client, access_key_id, secret_key, region)
          @api_client = api_client
          @ec2 = ::Aws::EC2::Resource.new(
            region: region, credentials: ::Aws::Credentials.new(access_key_id, secret_key)
          )
        end

        # @param [Hash] opts
        def run!(opts)
          ami = resolve_ami(client.region)
          abort('No valid AMI found for region') unless ami

          security_group = ensure_security_group(opts[:grid], opts[:vpc])
          name = opts[:name ] || generate_name

          opts[:vpc] = default_vpc.vpc_id unless opts[:vpc]
          if opts[:subnet].nil?
            subnet = default_subnet(opts[:vpc], ec2.client.config.region+opts[:zone])
          else
            subnet = ec2.subnet(opts[:subnet])
          end
          dns_server = aws_dns_supported?(opts[:vpc]) ? '169.254.169.253' : '8.8.8.8'
          userdata_vars = {
            name: name,
            version: opts[:version],
            master_uri: opts[:master_uri],
            grid_token: opts[:grid_token],
            dns_server: dns_server
          }

          ec2_instance = ec2.create_instances({
            image_id: ami,
            min_count: 1,
            max_count: 1,
            instance_type: opts[:type],
            security_group_ids: [security_group.group_id],
            key_name: opts[:key_pair],
            subnet_id: subnet.subnet_id,
            user_data: Base64.encode64(user_data(userdata_vars)),
            block_device_mappings: [
              {
                device_name: '/dev/xvda',
                virtual_name: 'Root',
                ebs: {
                  volume_size: opts[:storage],
                  volume_type: 'gp2'
                }
              }
            ]
          }).first
          ec2_instance.create_tags({
            tags: [
              {key: 'Name', value: name},
              {key: 'kontena_grid', value: opts[:grid]}
            ]
          })

          ShellSpinner "Creating AWS instance #{name.colorize(:cyan)} " do
            sleep 5 until ec2_instance.reload.state.name == 'running'
          end
          node = nil
          ShellSpinner "Waiting for node #{name.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} " do
            sleep 2 until node = instance_exists_in_grid?(opts[:grid], name)
          end
          labels = ["region=#{client.region}", "az=#{opts[:zone]}"]
          set_labels(node, labels)
        end

        ##
        # @param [String] grid
        # @return [Aws::EC2::SecurityGroup]
        def ensure_security_group(grid, vpc_id)
          group_name = "kontena_grid_#{grid}"
          sg = ec2.security_groups({
            filters: [
              {name: 'group-name', values: [group_name]},
              {name: 'vpc-id', values: [vpc_id]}
            ]
          }).first
          unless sg
            ShellSpinner "Creating AWS security group" do
              sg = create_security_group(group_name, vpc_id)
            end
          end
          sg
        end

        ##
        # creates security_group and authorizes default port ranges
        #
        # @param [String] name
        # @param [String] vpc_id
        # @return [Aws::EC2::SecurityGroup]
        def create_security_group(name, vpc_id)
          sg = ec2.create_security_group({
            group_name: name,
            description: "Kontena Grid",
            vpc_id: vpc_id
          })

          sg.authorize_ingress({
            ip_protocol: 'tcp', from_port: 22, to_port: 22, cidr_ip: '0.0.0.0/0'
          })
          sg.authorize_ingress({
            ip_protocol: 'tcp', from_port: 80, to_port: 80, cidr_ip: '0.0.0.0/0'
          })
          sg.authorize_ingress({
            ip_protocol: 'tcp', from_port: 443, to_port: 443, cidr_ip: '0.0.0.0/0'
          })
          sg.authorize_ingress({
            ip_protocol: 'udp', from_port: 1194, to_port: 1194, cidr_ip: '0.0.0.0/0'
          })
          sg.authorize_ingress({
            ip_protocol: 'tcp', from_port: 6783, to_port: 6783,
            source_security_group_name: sg.group_id,
            source_security_group_owner_id: sg.owner_id
          })
          sg.authorize_ingress({
            ip_protocol: 'udp', from_port: 6783, to_port: 6784,
            source_security_group_name: sg.group_id,
            source_security_group_owner_id: sg.owner_id
          })

          sg
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def instance_exists_in_grid?(grid, name)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == name}
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        # @param [Hash] node
        # @param [Array<String>] labels
        def set_labels(node, labels)
          data = {}
          data[:labels] = labels
          api_client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
        end

        # @param [String] vpc_id
        # @return [Boolean]
        def aws_dns_supported?(vpc_id)
          vpc = ec2.vpc(vpc_id)
          response = vpc.describe_attribute({attribute: 'enableDnsSupport'})
          response.enable_dns_support
        end
      end
    end
  end
end
