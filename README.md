Github Issues to Jira via JSON
==============================

JIRA now provides a JSON import facility that is vastly easier to use than the CSV one.

This is a simple script to generate a JSON file for this import from the GitHub Issues v3 API.

https://confluence.atlassian.com/pages/viewpage.action?pageId=293830712

Running
-------

Copy config/config.yml.sample to config/config.yml and update config/usermap.yml

```bash
bundle install
rake generate_json
```

TODO
----

- Attachments
- Open/Close History
- Converting references to something Jira-friendly

