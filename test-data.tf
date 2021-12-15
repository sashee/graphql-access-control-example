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

