require 'date'
require 'json'
require 'aws-sdk-resources'

REGION='us-west-2'
CA_FILE = File.expand_path('../../ca-bundle.crt', __FILE__)

task :connect do
  secrets = File.expand_path('../../secrets.json', __FILE__)
  creds = JSON.load(File.read(secrets))
  Aws.config[:credentials] = Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])
  Aws.config[:region] = REGION
  Aws.config[:ssl_ca_bundle] = CA_FILE
end

def log msg
  puts '-'*3 + "> #{msg}"
end
