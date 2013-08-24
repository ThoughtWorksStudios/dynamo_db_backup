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

  begin
    file = Tempfile.open("dynamo_db", File.dirname(__FILE__))
    file << "["

    loop do
      data = client.scan(options).data
      puts "count: #{data[:count].inspect}, scanned_count: #{data[:scanned_count].inspect}, batch: #{data[:member].map(&:inspect)}\n\n"

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
    bucket.objects[table_name].write(:file => file.path)
  ensure
    file.close
    file.unlink
  end
end

backup_dynamo_db
