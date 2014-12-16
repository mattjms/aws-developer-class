require 'json'
require 'aws-sdk-resources'

def credentials
  @credentials ||= begin
    secrets = File.expand_path('../../secrets.json', __FILE__)
    creds = JSON.load(File.read(secrets))
    Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])
  end
end

def client
  @client ||= begin
    Aws.config[:credentials] = credentials
    Aws.config[:region] = 'us-east-1'
    Aws::Client.new
  end
end

def ec2
  @ec2 ||= Aws::EC2::Resource.new client: client
end

task :connect do
  puts ec2.inspect
end

