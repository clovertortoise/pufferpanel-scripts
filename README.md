# pufferpanel-scripts

Management scripts for pufferpanel servers.

- Designed to automate backups and updates / restarts
- Scheduled with cron for minimal user intervention

---
To setup, 

Replace the "<-pufferpanel api->" placholders with your own details,
and then add a new cron entry. You can use the following command to open and edit cron:
```
crontab -e
```
if you input something like the following example with your script location, it will run every morning at 5:55.
```
55 5 * * * /<scriptlocation>/<scriptname.sh>
```

