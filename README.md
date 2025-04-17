# pufferpanel-scripts

Management scripts for pufferpanel servers. Designed to be scheduled with cron to automate backups and updates with minimal user intervention.

1. [auto-puffer.sh](/auto-puffer.sh) (General Servers) Shuts down, backs up and restarts via the Pufferpanel API.
2. [mc-mgr.sh](/mc-mgr.sh) (Minecraft Bedrock) Notifies players before it shuts down, backs up, updates and restarts.

- Both scripts overwrite the oldest backup if there are more than 7. (This can be changed using the MAX_BACKUPS variable)
- Both scripts overwrite the latest backup if a backup already occured that day.


---
To setup, 

Replace the "<-pufferpanel api->" and "<-server_id->" placholders with your own details, (server ids can be found at /var/lib/pufferpanel/servers/)
and then add a new cron entry. You can use the following command to open and edit cron:
```
crontab -e
```
if you input something like the following example, with your script location, it will run every morning at 5:55.
```
55 5 * * * /<scriptlocation>/<scriptname.sh>
```
