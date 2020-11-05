#!/usr/bin/env ruby
#
# This script will purge all the contents of the S3 buckets provided as parameter to the CLI
# To run this script you'll need to run: sudo gem install aws-sdk-s3

require 'aws-sdk-s3'
require 'readline'

if ARGV.length < 2
  puts "usage: {$PROGRAM_NAME} <aws-cli-profile-name> <bucket_name> <bucket_name> <bucket_name> ..."
end

def delete_all_objects(s3, bucket_name)
  continuation_token = nil
  counter = 0
  loop do
    list_params = {
        bucket: bucket_name,
        max_keys: 1000,
        continuation_token: continuation_token,
        fetch_owner: false
    }
    list_result = s3.list_objects_v2(list_params)
    continuation_token = list_result.next_continuation_token

    if list_result.contents.length == 0
      puts "#{bucket_name} is already empty"
      break
    end

    objects = list_result.contents.map {|entry| {key: entry.key} }
    delete_params = {
      bucket: bucket_name,
      delete: {
        objects: objects,
        quiet: false
      }

    }

    puts "deleting #{objects.length} objects..."
    delete_result = s3.delete_objects(delete_params)

    delete_result.deleted.each {
      counter = counter + 1
    }

    delete_result.errors.each { |error|
      puts "failed to delete #{bucket_name}/#{error.key}"
    }

    break if continuation_token == nil
  end
  puts "#{counter} objects deleted."
end

profile = ARGV[0]
buckets_to_purge = []

ARGV.drop(1).each {|bucket_name|
  unless bucket_name =~ /lightspeed-aws-(va|oh)-[1-5]/
    puts "Invalid bucket name, bucket name must conform to lightspeed-aws-(va|oh)-[1-5]/"
    next
  end

  user_input = Readline.readline(
      'WARNING: This operation cannot be undone, if you\' re sure you want to permanently '\
      "delete all objects in #{bucket_name}, confirm the operation by retyping the bucket name: ",
      false)

  if user_input == bucket_name
    buckets_to_purge << user_input
  else
    puts "Skipping #{bucket_name}"
  end
  puts ""
}

buckets_to_purge.each {|bucket_name|
  region = if bucket_name =~ /lightspeed-aws-va/
             'us-east-1'
           elsif bucket_name =~ /lightspeed-aws-oh/
             'us-east-1'
           else
             raise "unexpected bucket name: #{bucket_name}"
           end
  s3 = Aws::S3::Client.new({region: region, profile: profile})
  delete_all_objects(s3, bucket_name)
}
