import json
import re
import sys

def main():
    try:
        with open('scraper_html.html', 'r', encoding='utf-8') as f:
            html = f.read()
        
        # Look for window.APP_INITIALIZATION_STATE=
        start_marker = 'window.APP_INITIALIZATION_STATE='
        end_marker = ';window.APP_FLAGS='
        
        start_idx = html.find(start_marker)
        if start_idx == -1:
            print("ERROR: APP_INITIALIZATION_STATE not found")
            return
            
        start_idx += len(start_marker)
        end_idx = html.find(end_marker, start_idx)
        if end_idx == -1:
            print("ERROR: APP_FLAGS not found after APP_INITIALIZATION_STATE")
            return
            
        json_str = html[start_idx:end_idx]
        
        # Parse it
        data = json.loads(json_str)
        
        print(f"Data is of type: {type(data)}")
        if isinstance(data, list):
            print(f"List length: {len(data)}")
            for i, item in enumerate(data):
                item_preview = str(item)[:100]
                print(f"Item {i} type: {type(item)}, preview: {item_preview}")
        
        with open('extracted_data.json', 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
            
        print("Success! Wrote extracted_data.json")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()
