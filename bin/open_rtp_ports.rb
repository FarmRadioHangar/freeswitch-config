#!/usr/bin/env ruby

class RtpPortOpener
  require 'json'

  MIN_RTP_START_PORT = 16384
  DEFAULT_RTP_START_PORT = MIN_RTP_START_PORT
  MAX_RTP_END_PORT = 32768
  DEFAULT_NUM_RTP_CHANNELS = 100
  DEFAULT_DOCKERRUN_PATH = File.expand_path('../Dockerrun.aws.json', __dir__)

  attr_accessor :rtp_start_port, :rtp_end_port, :dockerrun_path,
                :dockerrun_json, :existing_non_rtp_port_mappings,
                :rtp_port_mappings

  def open_ports!
    fetch_rtp_start_port!
    fetch_rtp_end_port!
    fetch_dockerrun_path!
    parse_dockerrun_json!
    find_existing_non_rtp_port_mappings
    generate_rtp_port_mappings
    write_new_dockerrun
    print_output
  end

  private

  def write_new_dockerrun
    container_definitions = dockerrun_json["containerDefinitions"] ||= []
    container_definition = container_definitions[0] ||= {}
    container_definition["portMappings"] = existing_non_rtp_port_mappings + rtp_port_mappings
    File.open(dockerrun_path, 'w') { |file| file.write(JSON.pretty_generate(dockerrun_json)) }
  end

  def find_existing_non_rtp_port_mappings
    self.existing_non_rtp_port_mappings = (((dockerrun_json["containerDefinitions"] || [])[0] || {})["portMappings"] || []).select do |port_mapping|
      pm = port_mapping["hostPort"].to_i
      pm < MIN_RTP_START_PORT || pm > MAX_RTP_END_PORT
    end
  end

  def generate_rtp_port_mappings
    self.rtp_port_mappings ||= []
    (rtp_start_port..rtp_end_port).each do |rtp_port|
      self.rtp_port_mappings << generate_rtp_port_mapping(rtp_port)
    end
  end

  def generate_rtp_port_mapping(rtp_port)
    {
      "hostPort" => rtp_port,
      "containerPort" => rtp_port,
      "protocol": "udp"
    }
  end

  def print_output
    puts ""
    puts "***************************"
    puts "Added RTP Ports to #{dockerrun_path}"
    puts "Don't forget to open the RTP ports in your security group and set the following configuration in your freeswitch_secrets.xml"
    puts "
    <X-PRE-PROCESS cmd=\"set\" data=\"rtp_start_port=#{rtp_start_port}\"/>
    <X-PRE-PROCESS cmd=\"set\" data=\"rtp_end_port=#{rtp_end_port}\"/>
    "
    puts "***************************"
  end

  def parse_dockerrun_json!
    self.dockerrun_json = JSON.parse(File.read(dockerrun_path))
  end

  def fetch_rtp_start_port!
    self.rtp_start_port = get_user_input("Enter RTP start port", DEFAULT_RTP_START_PORT).to_i
    raise(ArgumentError, "RTP start port must be greater than or equal to #{MIN_RTP_START_PORT}") if rtp_start_port < MIN_RTP_START_PORT
  end

  def fetch_rtp_end_port!
    num_rtp_channels = get_user_input("Enter number of desired RTP channels", DEFAULT_NUM_RTP_CHANNELS).to_i
    self.rtp_end_port = rtp_start_port + num_rtp_channels - 1

    raise(ArgumentError, "You must have at least 1 channel!") if rtp_end_port < rtp_start_port
    raise(ArgumentError, "Maximum number of channels is #{MAX_RTP_END_PORT - MIN_RTP_START_PORT}") if rtp_end_port > MAX_RTP_END_PORT
  end

  def fetch_dockerrun_path!
    self.dockerrun_path = get_user_input("Enter path for Dockerrun.aws.json", DEFAULT_DOCKERRUN_PATH)
    raise(ArgumentError, "File does not exist #{dockerrun_path}") if !File.exists?(dockerrun_path)
  end

  def get_user_input(message, default)
    print(message + " (defaults to #{default}): ")
    result = gets.strip
    result.empty? ? default : result
  end
end

rtp_port_opener = RtpPortOpener.new
rtp_port_opener.open_ports!
