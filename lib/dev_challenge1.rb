require 'net/http'
require 'ImageResize'

namespace :dev_challenge1 do

  URLS = %w(http://photojournal.jpl.nasa.gov/jpeg/PIA17563.jpg
            http://photojournal.jpl.nasa.gov/jpeg/PIA13316.jpg
            http://www.noaanews.noaa.gov/stories2014/images/ingridmanuel_tmo_2013258_lrg.jpg
            http://solarsystem.nasa.gov/multimedia/gallery/PIA03149.jpg
            http://apod.nasa.gov/apod/image/0610/antennae_hst_big.jpg)

  task send_image_message: 'lab3_1:create_queue' do
    log queue.inspect
    msg = queue.send_message message_body: URLS.join("\n")
  end

  # challenge #1
  # depends on lab2_1:create_bucket
  task process_messages: 'lab3_1:create_queue' do
    while (messages = queue.receive_messages).size > 0
      messages.each do |msg|
        msg.change_visibility visibility_timeout: 10
        urls = msg.body.split
        urls.each do |url|
          log "processing image: #{url}"
          uri = URI url
          small_image = resize_image(Net::HTTP.get(uri))
          s3_client.put_object(
            bucket: BUCKET_NAME,
            key: "thumbnails/#{s3_key(uri)}",
            body: small_image
          )
          small_image.close || small_image.unlink
        end
        msg.delete
      end
    end
  end

  # challenge #2
  # depends on lab2_1:create_bucket
  task upload_images: :connect do
    URLS.each do |url|
      log "processing url: #{url}"
      signed_uri = URI(Aws::S3::Presigner.new.presigned_url :put_object,
                       bucket: BUCKET_NAME, key: "presigned/#{s3_key(URI url)}")
      req = Net::HTTP::Put.new "#{signed_uri.path}?#{signed_uri.query}"
      req.body = Net::HTTP.get(uri)
      http_handler(signed_uri).request(req)
    end
  end

  task download_images: :connect do
    URLS.each do |url|
      log "processing url: #{url}"
      signed_uri = URI(Aws::S3::Presigner.new.presigned_url :get_object,
                       bucket: BUCKET_NAME, key: "presigned/#{s3_key(URI url)}")
      req = Net::HTTP::Get.new "#{signed_uri.path}?#{signed_uri.query}"
      response = http_handler(signed_uri).request(req)
      file = File.join 'data', File.basename(URI(url).path)
      File.open(file, 'wb'){ |fd| fd.write response.body }
    end
  end

  def s3_key uri
    "#{uri.host}/#{uri.path.gsub %r(^/|/$), ''}"
  end

  def http_handler uri
    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = true
    http.ca_file = CA_FILE
    #http.set_debug_output STDOUT
    http
  end

  def resize_image data
    input,output = %w(in out).map{ |pre| Tempfile.new [pre, '.jpg'] }
    begin
      input.binmode.write data
      input.close
      Image.resize input.path, output.path, 100, 100
      output.open
      return output
    ensure
      input.close || input.unlink
    end
  end
end
