require "rubygems"
require "bundler/setup"

Bundler.setup

require "aws"
require 'tempfile'

def get_env(key_name)
  var_name = key_name.to_s.upcase
  ENV[var_name] || raise("missing #{var_name} environment variable!")
end

AWS.config(
 :access_key_id => get_env(:access_key_id),
 :secret_access_key => get_env(:secret_access_key),
 :region => get_env(:region),
 :dynamo_db => {:api_version => "2012-08-10"}
)

def backup_dynamo_db
  puts "Backing up DynamoDB table #{get_env(:dynamo_db_table)} to #{get_env(:s3_bucket_name)}"
  bucket = AWS::S3.new.buckets[get_env(:s3_bucket_name)]
  client = AWS::DynamoDB::Client.new
  table_name = get_env(:dynamo_db_table)
  options = {
    :table_name => table_name,
    :select => "ALL_ATTRIBUTES"
  }

  start = Time.now

  begin
    file = Tempfile.open("dynamo_db", File.dirname(__FILE__))
    file << "["

    loop do
      data = client.scan(options).data
      puts "fetched data, count: #{data[:count].inspect}, scanned_count: #{data[:scanned_count].inspect}"

      if data[:member].size > 0
        batch = data[:member].to_json

        file << "," if options.has_key? :exclusive_start_key
        file << batch[1, batch.size-2]
      end

      if data[:last_evaluated_key]
        puts "last_evaluated_key => #{data[:last_evaluated_key].inspect}"
        options.merge!(:exclusive_start_key => data[:last_evaluated_key])
      else
        break
      end
    end

    file << "]"
    file.close
    puts "Fetched all DynamoDB table data in #{Time.now - start} seconds"

    s3start = Time.now
    bucket.objects[table_name].write(:file => file.path)
    puts "Uploaded to S3 in #{Time.now - s3start} seconds"
  ensure
    file.close
    file.unlink
  end

  puts "Backed up in #{Time.now - start} seconds"
end

backup_dynamo_db
