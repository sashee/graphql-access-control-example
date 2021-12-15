resource "aws_appsync_function" "Query_allUsers_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.users.name
	name = "Query_allUsers_1"
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
	name = "Query_allUsers_2"
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

