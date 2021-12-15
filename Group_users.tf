resource "aws_appsync_function" "Group_users_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Group_users_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Query",
	"query": {
		"expression": "#group = :group",
		"expressionNames": {
			"#group": "group"
		},
		"expressionValues": {
			":group": {"S": $util.toJson($ctx.source.id)}
		}
	},
	"index": "groups"
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_resolver" "Group_users" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Group"
  field       = "users"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Group_users_1.function_id,
    ]
  }
}

