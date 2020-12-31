#!/bin/bash

date=`date '+%d-%m-%y'`

config=$1
domains=$2
out_of_scope=$3

if [ "$#" -lt 2 ]; then
    echo "Correct usage: $0 <config file> <list of domains> [list of out of scope patterns]"
    exit
fi

function scan_domain {
    domain=$1

    if [ ! -d $PWD/passive-subdomains/$domain ]; then
        mkdir $PWD/passive-subdomains/$domain || $(echo "Failed to create passive-subdomains/$domain directory."; return)
    fi

    if [ ! -d $PWD/valid-subdomains/$domain ]; then
        mkdir $PWD/valid-subdomains/$domain || $(echo "Failed to create valid-subdomains/$domain directory."; return)
    fi

    echo "Starting scan on $domain."

    echo "Running Subfinder..."
    subfinder_output=`subfinder -all -config .subfinder.config -d $domain -silent`
    echo "Got $(wc -l <<< $subfinder_output) possible subdomains."

    echo 'Running Amass...'
    amass_output=`amass enum -passive -d $domain 2>/dev/null`
    echo "Got $(wc -l <<< $amass_output) possible subdomains."

    passive_subdomains=`echo "$subfinder_output $amass_output" | sort | uniq`
    echo "Found a total of $(wc -l <<< $passive_subdomains) possible subdomains."
    echo "$passive_subdomains" > $PWD/passive-subdomains/$domain/$date

    echo 'Validating subdomains with dnsx...'
    valid_subdomains=`echo "$passive_subdomains" | dnsx -silent -r 1.1.1.1,1.0.0.1 | sort`
    echo "Found a total of $(wc -l <<< $valid_subdomains) valid subdomains."

    if [ "$out_of_scope" != "" ] && [ -f $out_of_scope ] && [ -r $out_of_scope ]; then
        echo "Removing $(echo "$valid_subdomains" | grep -f $out_of_scope | wc -l) out of scope domains."
        valid_subdomains=`echo "$valid_subdomains" | grep -f $out_of_scope -v`
    elif [ -f $out_of_scope ]; then
        echo "Out of scope file isn't readable, can't filter out domains."
    fi

    echo "$valid_subdomains" > $PWD/valid-subdomains/$domain/$date

    previous_file=`ls -ltr $PWD/valid-subdomains/$domain/ | sed 'x;$!d' | awk '{print $9}'`

    if [ "$previous_file" = "" ]; then
        webhook_title="(NEW) Subdomains for $domain domain."
        webhook_message=`diff -u /dev/null $PWD/valid-subdomains/$domain/$date`
    elif cmp -s $PWD/valid-subdomains/$domain/$previous_file $PWD/valid-subdomains/$domain/$date; then
        echo "No change in subdomains, not sending webhook."
        return
    else
        webhook_title="Subdomain changes for $domain domain."
        webhook_message=`diff -u $PWD/valid-subdomains/$domain/$previous_file $PWD/valid-subdomains/$domain/$date`
    fi

    echo "Sending Discord webhook."
    echo "$webhook_message" | sed "s|$PWD/valid-subdomains/||g" | python3 $PWD/discord-webhook.py "$WEBHOOK_URL" "$webhook_title" $PWD/valid-subdomains/$domain/$date

}

# Check existence of domains and .config files
if [ ! -r $config ]; then
    echo "Config file doesn't exist or isn't readable."
    exit
fi

if [ ! -r $domains ]; then
    echo "Domains file doesn't exist or isn't readable."
    exit
fi

# Check if output directories exist, create if not

if [ ! -d $PWD/passive-subdomains ]; then
    mkdir $PWD/passive-subdomains || $(echo 'Failed to create passive-subdomains directory.'; exit)
fi

if [ ! -d $PWD/valid-subdomains ]; then
    mkdir $PWD/valid-subdomains || $(echo 'Failed to create passive-subdomains directory.'; exit)
fi

# Load config, read list of domains and scan each one
. $config

while read domain; do
    scan_domain $domain;
done < $domains
