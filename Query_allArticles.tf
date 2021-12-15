resource "aws_appsync_function" "Query_allArticles_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.articles.name
	name = "Query_allArticles_1"
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
$util.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_resolver" "Query_allArticles" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "allArticles"

  request_template = "{}"
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_allArticles_1.function_id,
    ]
  }
}
