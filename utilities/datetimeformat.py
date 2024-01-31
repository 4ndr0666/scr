import argparse
import datetime
from dateutil import parser

class CustomDateFormatter:
     def __init__(self):
        self.date_formats = {
            'us': '%m/%d/%Y',
            'uk': '%d/%m/%Y',
            'iso': '%Y-%m-%d'
        }

        self.time_formats = {
            '12h': '%I:%M %p',
            '24h': '%H:%M'
        }

    def format_date(self, date, format):
        if format in self.date_formats:
            return date.strftime(self.date_formats[format])
        else:
            raise ValueError('Invalid date format')

    def format_time(self, time, format):
        if format in self.time_formats:
            return time.strftime(self.time_formats[format])
        else:
            raise ValueError('Invalid time format')

    def format_datetime(self, dt, date_format, time_format):
        formatted_date = self.format_date(dt, date_format)
        formatted_time = self.format_time(dt, time_format)
        return f'{formatted_date} {formatted_time}'

def main():
    parser = argparse.ArgumentParser(description='Custom Date and Time Formatter')
    parser.add_argument('-d', '--date', type=str, required=True, help='Date in the format YYYY-MM-DD or MM/DD/YYYY or DD/MM/YYYY')
    parser.add_argument('-t', '--time', type=str, required=True, help='Time in the format HH:MM or HH:MM AM/PM')
    parser.add_argument('-df', '--date-format', type=str, required=True, choices=['us', 'uk', 'iso'], help='Output date format: us (MM/DD/YYYY), uk (DD/MM/YYYY), or iso (YYYY-MM-DD)')
    parser.add_argument('-tf', '--time-format', type=str, required=True, choices=['12h', '24h'], help='Output time format: 12h (hh:mm AM/PM) or 24h (HH:MM)')

    args = parser.parse_args()
    try:
        dt = parser.parse(args.date + ' ' + args.time)
    except ValueError as e:
        print(f'Error: {e}')
        return

    formatter = CustomDateFormatter()
    formatted_datetime = formatter.format_datetime(dt, args.date_format, args.time_format)
    print(formatted_datetime)

if __name__ == '__main__':
    main()
