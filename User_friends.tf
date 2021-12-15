resource "aws_appsync_function" "User_friends_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "User_friends_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "TransactGetItems",
	"transactItems": [
		#foreach($friend in $ctx.source.friends)
			{
				"table": "${aws_dynamodb_table.users.name}",
				"key" : {
					"username": {"S": $util.toJson($friend)}
				}
			}
		#if($foreach.hasNext),#end
		#end
	]
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_resolver" "User_friends" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "User"
  field       = "friends"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.User_friends_1.function_id,
    ]
  }
}

