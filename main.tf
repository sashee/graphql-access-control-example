provider "aws" {
}

data "aws_region" "current" {}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "cognito-test"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "ALLOW"
    user_pool_id   = aws_cognito_user_pool.pool.id
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}
data "aws_iam_policy_document" "appsync_push_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_push_logs.json
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "dynamodb:GetItem",
			"dynamodb:Query",
			"dynamodb:Scan",
    ]
    resources = [
			aws_dynamodb_table.users.arn,
			aws_dynamodb_table.groups.arn,
			aws_dynamodb_table.articles.arn,
    ]
  }
}

resource "aws_iam_role_policy" "appsync" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

# data sources

resource "aws_appsync_datasource" "users" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "users"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.users.name
  }
}

resource "aws_appsync_datasource" "groups" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "groups"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.groups.name
  }
}

resource "aws_appsync_datasource" "articles" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "articles"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.articles.name
  }
}

# resolvers

resource "aws_appsync_function" "Query_user_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_user_1"
  request_mapping_template = <<EOF
#if ($ctx.identity.username != $ctx.args.username)
	$util.unauthorized()
#else
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"username": {"S": $util.toJson($ctx.args.username)}
	},
	"consistentRead" : true
}
#end
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Query_user" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "user"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_user_1.function_id,
    ]
  }
}

resource "aws_appsync_function" "Query_allUsers_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_documents_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"username": {"S": $util.toJson($ctx.identity.username)}
	},
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.qr($ctx.stash.put("user", $ctx.result))
{}
EOF
}

resource "aws_appsync_function" "Query_allUsers_2" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_user_2"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan",
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#set($results = [])
#foreach($res in $ctx.result.items)
	#if($ctx.stash.user.group == $res.group)
		$util.qr($results.add($res))
	#end
#end
$util.toJson($results)
EOF
}

resource "aws_appsync_resolver" "Query_allUsers" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "allUsers"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_allUsers_1.function_id,
      aws_appsync_function.Query_allUsers_2.function_id,
    ]
  }
}

# cognito

resource "aws_cognito_user_pool" "pool" {
  name = "test-${random_id.id.hex}"
}

resource "aws_cognito_user_pool_client" "client" {
  name = "client"

  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.pool.id
}


# database

resource "aws_dynamodb_table" "users" {
  name           = "Users-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "username"

  attribute {
    name = "username"
    type = "S"
  }

  attribute {
    name = "group"
    type = "S"
  }

  global_secondary_index {
    name               = "groups"
    hash_key           = "group"
    projection_type    = "ALL"
  }
}

resource "aws_dynamodb_table" "groups" {
  name           = "Groups-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
resource "aws_dynamodb_table" "articles" {
  name           = "Articles-${random_id.id.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# sample data

locals {
	groups = tomap({
		group1 = {name: "Group 1"},
		group2 = {name: "Group 2"},
	})
	users = tomap({
		user1 = {cognito_group: aws_cognito_user_group.user, group: "group1", friends: ["user3"]},
		user2 = {cognito_group: aws_cognito_user_group.user, group: "group2", friends: []},
		user3 = {cognito_group: aws_cognito_user_group.user, group: "group1", friends: ["admin1"]},
		admin1 = {cognito_group: aws_cognito_user_group.admin, group: "group1", friends: []},
		admin2 = {cognito_group: aws_cognito_user_group.admin, group: "group2", friends: []},
	})
	articles = tomap({
		article1 = {text: "Lorem ipsum", author: "user1"},
		article2 = {text: "Dolor set ameth", author: "user2"},
	})
}

resource "null_resource" "cognito_user" {
	for_each = local.users

  provisioner "local-exec" {
    command = <<EOT
aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-create-user \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} \
	--user-attributes "Name=email,Value=${each.key}@example.com" 

aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-add-user-to-group \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} \
	--group-name ${each.value.cognito_group.name} >&2;

aws \
	--region ${data.aws_region.current.name} \
	cognito-idp admin-set-user-password \
	--user-pool-id ${aws_cognito_user_pool.pool.id} \
	--username ${each.key} \
	--password "Password.1" \
	--permanent >&2;
EOT
  }
}

resource "aws_dynamodb_table_item" "user" {
	for_each = local.users
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key
  range_key   = aws_dynamodb_table.users.range_key

  item = <<ITEM
{
  "username": {"S": "${each.key}"},
	"group": {"S": "${each.value.group}"},
	"friends": {"L": ${jsonencode([for v in each.value.friends : {"S": v}])}}
}
ITEM
}

resource "aws_dynamodb_table_item" "groups" {
	for_each = local.groups
  table_name = aws_dynamodb_table.groups.name
  hash_key   = aws_dynamodb_table.groups.hash_key
  range_key   = aws_dynamodb_table.groups.range_key

  item = <<ITEM
{
	"id": {"S": "${each.key}"},
  "name": {"S": "${each.value.name}"}
}
ITEM
}

resource "aws_dynamodb_table_item" "articles" {
	for_each = local.articles
  table_name = aws_dynamodb_table.articles.name
  hash_key   = aws_dynamodb_table.articles.hash_key
  range_key   = aws_dynamodb_table.articles.range_key

  item = <<ITEM
{
	"id": {"S": "${each.key}"},
  "text": {"S": "${each.value.text}"},
  "author": {"S": "${each.value.author}"}
}
ITEM
}
