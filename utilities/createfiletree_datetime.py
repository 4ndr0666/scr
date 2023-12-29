import os
from datetime import datetime, timedelta

def create_transcript_structure(base_path, years=2):
    current_year = datetime.now().year
    for year in range(current_year, current_year + years):
        year_path = os.path.join(base_path, str(year))
        os.makedirs(year_path, exist_ok=True)

        for month in range(1, 13):
            month_path = os.path.join(year_path, f"{month:02d} {datetime(year, month, 1).strftime('%B')}")
            os.makedirs(month_path, exist_ok=True)

            if month == 12:
                next_month = datetime(year + 1, 1, 1)
            else:
                next_month = datetime(year, month + 1, 1)

            for day in range(1, (next_month - timedelta(days=1)).day + 1):
                day_path = os.path.join(month_path, f"{day:02d}-{month:02d}-{year}")
                os.makedirs(day_path, exist_ok=True)

# Prompting for the path
user_input_path = input("Enter the path where you want to create the transcript structure: ")
create_transcript_structure(user_input_path)
