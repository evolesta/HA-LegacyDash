# Legacy Dash
A legacy HTML dashboard for Home Assistant which also works on older devices.

I had a old Ipad with Ios 9. But i was not able to run my Home Assistant dashboards on it, because the native app is not compatible with olders IOS versions. The webinterface could also not be used.
So i vibecoded a legacy HTML frontend for Home Assistant. It is developed with older IOS supported Javascript and CSS techniques, so it works just fine. 
All you need to do is host the index.html file and the /config/config.json file which hold your settings. 

The easiest way to host this app is by spinning it up in Docker. 

# Installation (Docker)
1. Generate a access token in Home Assistant
The app needs to access the HA API, which requires a token. 
Go to HAS, click on your profile and the Security tab. Scroll all the way down to long lived access tokens and click New. Give it a proper name and generate the token. 

2. Clone or download the repository on your Docker host
Use `git clone` or just download the repository and extract in a folder on your Docker host. 

3. Spin up the docker containers
Enter `docker compose up -d` in the repository folder to spin up the container. The image is built from source. 
You can use the .env.example file to preconfigure the app, but you can also do this in the UI afterwards. 

By default, the compose file uses a volume mount for the config.json file to store the apps settings outside the container.
It also binds port 8080 of the docker host to serve the app. Feel free to modify the compose file to your needs. 

## Installation (without Docker)
This is not recommended yet. It can work but the token is stores in config.json which is readable trough your webserver. Also there isn't any login. 