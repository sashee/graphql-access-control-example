resource "aws_appsync_function" "User_group_unsafe_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.groups.name
	name = "User_group_unsafe_1"
  request_mapping_template = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"id": {"S": $util.toJson($ctx.source.group)}
	},
	"consistentRead" : true
}
EOF

  response_mapping_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "User_group_unsafe" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "User"
  field       = "group_unsafe"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.User_group_unsafe_1.function_id,
    ]
  }
}

