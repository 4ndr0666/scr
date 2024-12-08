import subprocess
import requests
from bs4 import BeautifulSoup

# Function to extract stream URL from the website
def extract_stream_url(twitch_url):
    response = requests.get("http://pwn.sh/tools/getstream.html", params={"url": twitch_url})
    soup = BeautifulSoup(response.content, "html.parser")
    stream_url_input = soup.find("input", {"id": "stream_url"})
    if stream_url_input:
        stream_url = stream_url_input['value']
        return stream_url
    else:
        return None

# Prompt user for the Twitch video URL
twitch_url = input("Enter the Twitch video URL: ")

# Extract the stream URL using the website
extracted_url = extract_stream_url(twitch_url)

if extracted_url:
    # Format the extracted URL for yt-dlp downloading
    command = f"yt-dlp {extracted_url}"
    subprocess.run(command, shell=True)
else:
    print("Failed to extract the stream URL. Please check the Twitch video URL and try again.")
