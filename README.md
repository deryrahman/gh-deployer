# Github Deployer
Deploy multiple markdown-based repository to single Github Jekyll page. This project intented for personal use only.

## Features

- [x] Deploy markdown-based repo to gh page repository for every merged PR
- [x] Transform markdown header to Jekyll page title
- [x] Support new markdown page and modified markdown page

## Setup on GCP app engine
1. Clone this repo
2. Copy `app-sample.yml` to `app.yml`. Adjust `env_variables`
```
- ACCESS_TOKEN: <access token from https://github.com/settings/tokens>
- SECRET_TOKEN: <secret token from webhook https://developer.github.com/v3/guides/delivering-deployments/>
- EMAIL: <your github email>
```
3. Create an app
```sh
gcloud app create
```
3. Deploy
```sh
gcloud app deploy
```

## Usage

1. Create a webhook, pointing to `https://<domain>/deploy`. 
```
- Content Type: application/json
- Secret: <SECRET_TOKEN>
- SSL: Enable ssl verification
- Trigger webhook on Pull Requests
```
2. Make a pull request. Once it merge, it will deploy to the `<username>.github.io`
