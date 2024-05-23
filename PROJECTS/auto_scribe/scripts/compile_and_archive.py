import subprocess
import shutil
import os
import logging
from threading import Timer

SANDBOX_PATH = "/mnt/data/sandbox"

def compile_markdown_to_pdf():
    compile_command = """
    pandoc -s -o {output} {files}
    """.format(
        output=os.path.join(SANDBOX_PATH, "data", "Final", "final_guide.pdf"),
        files=" ".join([os.path.join(SANDBOX_PATH, "data", section, "*.md") for section in [
            "Introduction", "Preparation", "System Backup", "Recovery and Repair",
            "Automation Scripts", "Testing and Validation", "Advanced Topics",
            "Troubleshooting", "Conclusion"
        ]])
    )
    try:
        subprocess.run(compile_command, shell=True, check=True)
        logging.info("Markdown files compiled to PDF successfully.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to compile Markdown files to PDF: {e}")

def process_and_compress(directory_path, target_dir=os.path.join(SANDBOX_PATH, 'results'), archive_format='zip'):
    if not os.path.isdir(directory_path):
        logging.error(f"The specified directory does not exist: {directory_path}")
        return None

    os.makedirs(target_dir, exist_ok=True)

    try:
        archive_name = os.path.join(target_dir, os.path.basename(directory_path))
        archive_path = shutil.make_archive(base_name=archive_name, format=archive_format, root_dir=directory_path)
        logging.info(f"Directory successfully compressed into: {archive_path}")
        return archive_path
    except Exception as e:
        logging.error(f"Failed to compress directory {directory_path}: {e}")
        return None

def schedule_pdf_compile(delay):
    Timer(delay, compile_markdown_to_pdf).start()
    logging.info(f"PDF compilation scheduled in {delay} seconds.")
