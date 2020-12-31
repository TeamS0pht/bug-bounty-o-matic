# bug-bounty-o-matic

## Configuration
`domains`: List of root domains to scan
```
example.com
example-dev.com
example-example.example
```

`out-of-scope`: List of Regex patterns for out of scope domains to be filtered out
```bash
^\(.*\.\)\?example.com$ # Filter out domain and all subdomains
^outofscope.example.com$ # Filter out subdomain only
```

`.config`: Main config file, currently only needs a Discord webhook URL:
```bash
WEBHOOK_URL='URL'
```

Subfinder will also look for and create a `.subfinder.config` file if there isn't one already, API tokens can be added there to query more sources.
