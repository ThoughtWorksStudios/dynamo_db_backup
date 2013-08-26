dynamo_db_backup
================

Util to backup AWS DynamoDB to S3 without using DataPipline

Usage
-----

Set the following environment variables, and then run `./jruby backup_dynamo_db.rb`:

* `S3_BUCKET_NAME`
* `DYNAMO_DB_TABLE`
* `ACCESS_KEY_ID`
* `SECRET_ACCESS_KEY`
* `REGION`