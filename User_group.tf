resource "aws_appsync_function" "User_group_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "User_group_1"
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

resource "aws_appsync_function" "User_group_2" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.groups.name
	name = "User_group_2"
  request_mapping_template = <<EOF
#if($ctx.source.group != $ctx.stash.user.group)
	#return
#else
	{
		"version" : "2018-05-29",
		"operation" : "GetItem",
		"key" : {
			"id": {"S": $util.toJson($ctx.source.group)}
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

resource "aws_appsync_resolver" "User_group" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "User"
  field       = "group"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.User_group_1.function_id,
      aws_appsync_function.User_group_2.function_id,
    ]
  }
}

