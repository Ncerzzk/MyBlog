require "github_api"

# 本文件用于保存issue.rb 模板
# 因为 TOKEN不能上传到github中，否则会被删除
TOKEN =''
GITHUBAPI=Github.new oauth_token: TOKEN

def create_issue(title)
  GITHUBAPI.issues.create(user:"Ncerzzk",repo:"Myblog",title: title).number
end
