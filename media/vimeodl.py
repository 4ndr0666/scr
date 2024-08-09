import requests
import json
from urllib.parse import urlparse, parse_qs

# Function to extract video URLs
def extract_vimeo_video_urls(video_url):
    # Fetch the page
    response = requests.get(video_url)
    
    # Check for successful response
    if response.status_code != 200:
        print(f"Failed to retrieve the page: {response.status_code}")
        return
    
    # Extract JSON from the page content
    try:
        json_data = json.loads(response.text)
        files_data = json_data.get('request', {}).get('files', {})
        
        # Extract DASH and HLS URLs
        dash_url = get_cdn_url(files_data.get('dash', {}))
        hls_url = get_cdn_url(files_data.get('hls', {}))
        
        if dash_url:
            print(f"DASH URL: {dash_url}")
        
        if hls_url:
            print(f"HLS URL: {hls_url}")
            
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON: {e}")
        
# Helper function to extract URL from CDN data
def get_cdn_url(files):
    if not files:
        return None
    
    default_cdn = files.get('default_cdn', '')
    if not default_cdn:
        return None
    
    cdn_data = files.get('cdns', {}).get(default_cdn, {})
    return cdn_data.get('url', '')

# Extract video ID from the Vimeo URL
def extract_video_id(url):
    parsed_url = urlparse(url)
    path_segments = parsed_url.path.split('/')
    video_id = path_segments[-1] if path_segments[-1] else path_segments[-2]
    return video_id

# Construct the JSON URL based on the video ID
def construct_json_url(video_id):
    return f"https://player.vimeo.com/video/{video_id}/config"

# Main execution
vimeo_url = "https://player.vimeo.com/video/916757604?autoplay=1"
video_id = extract_video_id(vimeo_url)
json_url = construct_json_url(video_id)
extract_vimeo_video_urls(json_url)
