require "github_api"

TOKEN ='35dbdcf58cec119b0c835d9436c6046de1463f64'
GITHUBAPI=Github.new oauth_token: TOKEN

def create_issue(title)
  GITHUBAPI.issues.create(user:"Ncerzzk",repo:"Myblog",title: title).number
end
