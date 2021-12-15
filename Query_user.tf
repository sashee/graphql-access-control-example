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

