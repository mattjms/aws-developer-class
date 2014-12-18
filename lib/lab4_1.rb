require 'json'

namespace :lab4_1 do
  USER_NAME = 'LabAppUser'

  def iam_client
    @iam_client ||= Aws::IAM::Client.new
  end

  def iam_resource
    @iam_resource ||= Aws::IAM::Resource.new client: iam_client
  end

  task delete_user: :connect do
    user = iam_resource.user USER_NAME
    if user
      user.policies.map &:delete
      user.access_keys.map &:delete
      user.delete
    end
  end

  task create_user: :delete_user do
    user = iam_resource.create_user user_name: USER_NAME
    user.create_policy policy_name: 'AllowAssumeRole',
      policy_document: {
        'Statement' => [{
          'Action' => [ 'sts:AssumeRole' ],
          'Effect' => 'Allow',
          'Resource' => '*'
        }]}.to_json
    @keypair = user.create_access_key_pair
  end

  namespace :prep_mode do
    
    task get_user_arn: :create_user do
      @app_arn = iam_resource.user(USER_NAME).arn
      log @app_arn
    end

    task delete_roles: :get_user_arn do
      iam_resource.roles.each do |role|
        role.policies.map &:delete
        role.delete
      end
    end

    task create_roles: :delete_roles do
      trust = trust_policy(@app_arn)
      { 'development_role' => dev_role_policy,
        'production_role' => prod_role_policy }.each do |name, policy|
        role = iam_resource.create_role assume_role_policy_document: trust, role_name: name 
        iam_client.put_role_policy role_name: role.name, policy_name: "#{name}_policy", policy_document: policy
      end
    end
  end

  namespace :app_mode do
    def iam_app_client
      @iam_app_client ||= Aws::IAM::Client.new credentials:
        Aws::Credentials.new(@keypair.access_key_id, @keypair.secret_access_key)
    end

    def iam_app_resource
      @iam_app_resource ||= Aws::IAM::Resource.new client: iam_app_client
    end

  end
end


  def trust_policy arn
    { 'Version' => '2012-10-17',
      'Statement' => [{
        'Sid' => '',
        'Effect' => 'Allow',
        'Principal' => {
          'AWS' => arn
        },
        'Action' => 'sts:AssumeRole'
      }]}.to_json
  end

  def dev_role_policy
    { 'Statement' => [
        {
          'Sid' => 'Stmt1377797407113',
          'Action' => 's3:*',
          'Effect' => 'Allow',
          'Resource' => 'arn:aws:s3:::dev*'
        },
        {
          'Sid' => 'Stmt1377797472762',
          'Action' => 'iam:*',
          'Effect' => 'Allow',
          'Resource' => '*'
        },
        {
          'Sid' => 'Stmt1377797511645',
          'Action' => 'sns:*',
          'Effect' => 'Allow',
          'Resource' => '*'
        },
        {
          'Sid' => 'Stmt1377797524737',
          'Action' => 'sqs:*',
          'Effect' => 'Allow',
          'Resource' => '*'
        }]}.to_json
  end

  def prod_role_policy
    { 'Statement' => [
        {
          'Sid' => 'Stmt1377797715824',
          'Action' => [
            's3:AbortMultipartUpload',
            's3:DeleteObject',
            's3:DeleteObjectVersion',
            's3:GetBucketAcl',
            's3:GetBucketLocation',
            's3:GetBucketLogging',
            's3:GetBucketNotification',
            's3:GetBucketPolicy',
            's3:GetBucketRequestPayment',
            's3:GetBucketVersioning',
            's3:GetBucketWebsite',
            's3:GetLifecycleConfiguration',
            's3:GetObject',
            's3:GetObjectAcl',
            's3:GetObjectTorrent',
            's3:GetObjectVersion',
            's3:GetObjectVersionAcl',
            's3:GetObjectVersionTorrent',
            's3:ListAllMyBuckets',
            's3:ListBucket',
            's3:ListBucketMultipartUploads',
            's3:ListBucketVersions',
            's3:ListMultipartUploadParts',
            's3:PutObject',
            's3:PutObjectAcl',
            's3:PutObjectVersionAcl'
          ],
          'Effect' => 'Allow',
          'Resource' => 'arn:aws:s3:::prod*'
        }]}.to_json
  end
