require 'date'
require 'json'
require 'aws-sdk-resources'

task :connect do
  secrets = File.expand_path('../../secrets.json', __FILE__)
  creds = JSON.load(File.read(secrets))
  Aws.config[:credentials] = Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])
  Aws.config[:region] = 'us-west-2'
  Aws.config[:ssl_ca_bundle] = File.expand_path('../../ca-bundle.crt', __FILE__)
end

def log msg
  puts '-'*10 + "> #{msg}"
end

task lab2_1: :connect do
  def s3
    @s3 ||= Aws::S3::Resource.new
  end

  def list_buckets
    s3.buckets.each do |bucket|
      puts bucket.name
    end
  end

  def clear_buckets
    s3.buckets.each do |bucket|
      next unless bucket.name.match /^lab/
      log "Deleting #{bucket.inspect}"
      bucket.delete!
    end
  end

  task lab2_1: :connect do
    BUCKET = "lab2.1-#{Date.today.to_s}"
    begin
      clear_buckets
      log "Creating bucket #{BUCKET}"
      bucket = s3.create_bucket(
        bucket: BUCKET
      )
      list_buckets
    rescue => ex
      log ex.message
    ensure
      clear_buckets
    end
  end
end
