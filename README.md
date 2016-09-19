Github Issues to JIRA via JSON
==============================

JIRA now provides a JSON import facility that is vastly easier to use than the CSV one.

This is a simple script to generate a JSON file for this import from the GitHub Issues v3 API.

https://confluence.atlassian.com/pages/viewpage.action?pageId=293830712

Running
-------

Copy config.yml.sample to config.yml

```bash
bundle install --path=vendor/bundle
bundle exec ruby g2j.rb
```

TODO
----

- Attachments
