import sys, json, requests

class Webhook:
    def __init__(self, url):
        self.url = url
        self.data = {'embeds': []}
        self.files = {}

    def add_embed(self, title, desc):
        embed = {}
        embed['title'] = title
        embed['description'] = desc
        
        self.data['embeds'].append(embed)
        return len(self.data['embeds'])

    def add_file(self, file):
        self.files['_{}'.format(file)] = (file, open(file, 'rb').read())

    def send(self):
        if not self.files:
            result = requests.post(self.url, data=json.dumps(self.data), headers={'Content-Type': 'application/json'})
        else:
            self.files["payload_json"] = (None, json.dumps(self.data))
            result = requests.post(self.url, files=self.files)
        
        try:
            result.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print('Failed sending webhook:\n', err)
        else:
            print('Successfully sent comparison webhook.')

def main():

    argc = len(sys.argv)

    if argc < 3 or ' '.join(sys.argv[0:]).find('-h') != -1:
        print('Correct usage: %s <URL> <Embed Title> [Attached File]' % sys.argv[0])
        return
    else:
        webhook_url = sys.argv[1]
        embed_title = sys.argv[2]
    
    # To keep within Discord limits, input is split into chunks of 2000 characters
    # Each chunk is sent as a seperate embed, with this then being split further
    # into multiple messages if more than 2 embeds are filled
    
    webhook = Webhook(webhook_url)
    embed_desc = '```diff\n'

    for line in sys.stdin.readlines():
        if len(embed_desc) + len(line) > 2000:
            if webhook.add_embed(embed_title, embed_desc+'\n```') == 2:
                webhook.send()
                webhook = Webhook(webhook_url)
            embed_desc = '```diff\n'
        embed_desc += line
    
    webhook.add_embed(embed_title, embed_desc+'\n```')
    
    if argc >= 4:
        webhook.add_file(sys.argv[3])

    webhook.send()

if __name__ == "__main__":
    main()