namespace :lab2_1 do
  BUCKET_NAME = "lab2.1-#{Date.today.to_s}"

  def resource
    @resource ||= Aws::S3::Resource.new
  end

  def client
    @client ||= Aws::S3::Client.new
  end

  task create_bucket: [:connect, :destroy_buckets] do
    log "Creating bucket #{BUCKET_NAME}"
    params = { bucket: BUCKET_NAME }
    if REGION != 'us-east-1'
      params[:create_bucket_configuration] = { location_constraint: REGION }
    end
    resource.create_bucket params
  end

  task put_objects: :connect do
    %w(test-image.png test-image2.png).each do |file|
      client.put_object(
        bucket: BUCKET_NAME,
        key: file,
        body: File.new("data/#{file}")
      )
    end
  end

  task list_objects: :connect do
    client.list_objects(bucket: BUCKET_NAME).contents.each do |obj|
      puts obj.key
    end
  end

  task make_object_public: :connect do
    client.put_object_acl(
      acl: 'public-read',
      bucket: BUCKET_NAME,
      key: 'test-image2.png'
    )
  end

  task generate_presigned_url: :connect do
    signer = Aws::S3::Presigner.new
    puts signer.presigned_url(:get_object, bucket: BUCKET_NAME, key: 'test-image.png')
  end

  task list_buckets: :connect do
    resource.buckets.each do |bucket|
      puts bucket.name
    end
  end

  task destroy_buckets: :connect do
    resource.buckets.each do |bucket|
      next unless bucket.name.match /^lab/
      log "Deleting #{bucket.inspect}"
      begin
        bucket.delete!
      rescue => ex
        log ex.message
      end
    end
  end
end
