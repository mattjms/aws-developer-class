namespace :lab3_1 do
  QUEUE_NAME = 'Notifications'
  TOPIC_NAME = 'ClassroomEvent'

  def sns_resource
    @sns_resource ||= Aws::SNS::Resource.new
  end

  def sqs_resource
    @sqs_resource ||= Aws::SQS::Resource.new
  end

  def queue
    sqs_resource.queue @queue_url
  end

  def topic
    sns_resource.topic @topic_arn
  end

  task all: [ :create_queue, :get_queue_arn, :create_topic, :grant_notification_permission,
              :create_subscription, :publish_topic_message, :post_to_queue, :read_message,
              :delete_subscriptions, :delete_topic, :delete_queue ]

  task create_queue: :connect do
    log 'creating queue...'
    @queue_url = sqs_resource.create_queue(queue_name: QUEUE_NAME).url
    log "queue url is #{@queue_url}"
  end

  task get_queue_arn: :create_queue do
    log 'getting queue arn...'
    @queue_arn = queue.arn
    log "queue arn is #{@queue_arn}"
  end

  task create_topic: :get_queue_arn do
    log 'creating topic...'
    @topic_arn = sns_resource.create_topic(name: TOPIC_NAME).arn
    log "topic arn is #{@topic_arn}"
  end

  task grant_notification_permission: :create_topic do
    log 'granting notification permission...'
    policy = {
      "Version" => "2008-10-17",
      "Id" => "#{@queue_arn}/SQSDefaultPolicy",
      "Statement" => [
        {
          "Sid" => "Allow#{TOPIC_NAME}Publishing",
          "Effect" => "Allow",
          "Principal" => {
            "AWS" => "*"
          },
          "Action" => "SQS:SendMessage",
          "Resource" => @queue_arn,
          "Condition" => {
            "ArnLike" => {
              "aws:SourceArn" => "arn:aws:sns:us-west-2:776982171623:ClassroomEvent"
            }
          }
        }
      ]
    }
    queue.set_attributes attributes: { 'Policy' => policy.to_json }
    log "added permission"
  end

  task create_subscription: :grant_notification_permission do
    log 'creating subscription...'
    subscription = topic.subscribe protocol: 'sqs', endpoint: @queue_arn
    log "subscribed #{subscription.inspect}"
  end

  task publish_topic_message: :create_subscription do
    log 'publishing message to topic...'
    msg = topic.publish message: "this message was published to the topic", subject: "From Topic"
    log "published to topic #{msg}"
  end

  task post_to_queue: :get_queue_arn do
    log 'posting to queue...'
    msg = queue.send_message message_body: 'this message was posted to the queue'
    log "posted to queue #{msg}"
  end

  task read_message: :get_queue_arn do
    log 'reading message...'
    while (messages = queue.receive_messages).size > 0
      messages.each do |msg|
        log "message body: #{msg.body}"
        log "message md5 : #{msg.md5_of_body}"
        msg.delete
      end
    end
  end

  task delete_subscriptions: :create_subscription do
    log 'deleting subscriptions...'
    topic.subscriptions.map &:delete
  end

  task delete_topic: :create_topic do
    log 'deleting topic...'
    topic.delete
  end

  task delete_queue: :get_queue_arn do
    log 'deleting queue...'
    queue.delete
  end
end
